//
//  FatSecretSwift.swift
//  Take 10
//
//  Created by Nicholas Bellucci on 12/23/17.
//  Copyright © 2017 Nicholas Bellucci. All rights reserved.
//

import UIKit
import CryptoSwift

// HTTP Method: POST
// URL Request: http://platform.fatsecret.com/rest/server.api

// Params
// format:json
// oauth_consumer_key:**********
// oauth_signature_method:HMAC-SHA1
// oauth_timestamp:**********
// oauth_nonce:**********
// oauth_version:1.0
// oauth_signature:**********

public class FatSecretAPI {
    private var _key: String?
    private var _secret: String?
    
    // Getter and Setter for the OAuth Consumer Key
    // Setter will update the OAuth parameter dictionary
    public var key: String {
        set {
            _key = newValue
            Constants.oAuth.updateValue(_key!, forKey: "oauth_consumer_key")
        }
        get { return _key! }
    }
    
    // Getter and Setter for the OAuth Consumer Secret
    // Setter will concatenate an ampersand as there is no access key to follow
    public var secret: String {
        set {
            _secret = newValue
            Constants.key = "\(_secret!)&"
        }
        get { return _secret! }
    }
    
    // Public search food by name function
    // TODO: Add error handling
    public func searchFoodBy(name: String, completion: @escaping (_ foods: Search) -> Void) {
        Constants.fatSecret = ["format":"json", "method":"foods.search", "search_expression":name] as Dictionary
        
        let components = generateSignature()
        fatSecretRequestWith(components: components) { (data) in
            if let data = data {
                let model = self.retrieve(data: data, type: [String:Search].self)
                let search = model!["foods"]
                completion(search!)
            }
        }
    }
    
    // Public get food by id function
    // TODO: Add error handling
    public func getFoodBy(id: String, completion: @escaping (_ foods: Food) -> Void) {
        Constants.fatSecret = ["format":"json", "method":"food.get", "food_id":id] as Dictionary
        
        let components = generateSignature()
        fatSecretRequestWith(components: components) { (data) in
            if let data = data {
                let model = self.retrieve(data: data, type: [String:Food].self)
                let food = model!["food"]
                completion(food!)
            }
        }
    }
    
    // File private generate signature function
    // Uses the percent encoded signature base string and the consumer secret to HMAC-SHA1 encrypt
    fileprivate func generateSignature() -> URLComponents {
        Constants.oAuth.updateValue(self.timestamp, forKey: "oauth_timestamp")
        Constants.oAuth.updateValue(self.nonce, forKey: "oauth_nonce")
        
        var components = URLComponents(string: Constants.url)!
        components.createItemsForURLComponentsObject(array: Array<String>().parameters)
        
        let parameters = components.getURLParameters()
        let encodedURL = Constants.url.addingPercentEncoding(withAllowedCharacters: CharacterSet().percentEncoded)!
        let encodedParameters = parameters.addingPercentEncoding(withAllowedCharacters: CharacterSet().percentEncoded)!
        let signatureBaseString = "\(Constants.httpType)&\(encodedURL)&\(encodedParameters)".replacingOccurrences(of: "%20", with: "%2520")
        let signature = String().getSignature(key: Constants.key, params: signatureBaseString)
        
        components.queryItems?.append(URLQueryItem(name: "oauth_signature", value: signature))
        return components
    }
    
    // File private HTTP request to Fat Secret's REST API
    // Will throw errors based on the response
    fileprivate func fatSecretRequestWith(components: URLComponents, completion: @escaping (_ data: Data?)-> Void) {
        var request = URLRequest(url: URL(string: String(describing: components).replacingOccurrences(of: "+", with: "%2B"))!)
        request.httpMethod = Constants.httpType
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let data = data {
                do {
                    let model = self.retrieve(data: data, type: [String:FSError].self)
                    if model != nil {
                        let error = model!["error"]
                        try self.checkForErrorWith(code: error!.code)
                    }
                    
                    completion(data)
                } catch let error as NSError {
                    print(error.localizedDescription)
                }
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
        task.resume()
    }
    
    fileprivate func retrieve<T: Decodable>(data: Data, type: T.Type) -> T? {
        let decoder = JSONDecoder()
        do {
            let model = try decoder.decode(type, from: data)
            return model
        } catch {
            return nil
        }
    }
}

// FatSecretAPI class extension
// Provides the nonce and timestamp strings
extension FatSecretAPI {
    // Creates a timestamp for OAuth
    var timestamp: String {
        get { return String(Int(Date().timeIntervalSince1970)) }
    }
    
    // Creates a random set of 10 characters
    // The nonce is used for the OAuth process
    var nonce: String {
        get {
            var string: String = ""
            let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            let char = Array(letters)
            
            for _ in 1...7 { string.append(char[Int(arc4random()) % char.count]) }
            
            return string
        }
    }
    
    // File private error check
    fileprivate func checkForErrorWith(code: Int) throws {
        switch code {
        case 5:
            throw RequestError.InvalidKey
        case 8:
            throw RequestError.InvalidSignature
        default:
            throw RequestError.Unknown
        }
    }
}

////////////////////////////////////////////////
// Codable structs for JSON decoding and mapping
////////////////////////////////////////////////

// Codable Foods struct
// Allows for JSON decoding and mapping to object
public struct Search: Decodable {
    struct Food: Decodable {
        var id, name, description, brand, type, url: String?
        enum CodingKeys: String, CodingKey {
            case id = "food_id", name = "food_name", description = "food_description", brand = "brand_name", type = "food_type", url = "food_url"
        }
    }
    
    let foods: [Food]
    enum CodingKeys: String, CodingKey {
        case foods = "food"
    }
}

// Codable Food struct
// Allows for JSON decoding and mapping to object
public struct Food {
    var id, name, type: String?
    var servings: Array<Serving>?
    
    init(id: String, name: String, type: String, servings: [Serving]) {
        self.id = id
        self.name = name
        self.type = type
        self.servings = servings
    }
}

// Food extension
// Custom init logic for the decoder to determine the value type of servings
extension Food: Decodable {
    enum CodingKeys: String, CodingKey {
        case id = "food_id", name = "food_name", type = "food_type", servings
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let type = try container.decode(String.self, forKey: .type)
        
        do {
            let servings = try container.decode([String:Serving].self, forKey: .servings)
            let array = [servings["serving"]!]
            self.init(id: id, name: name, type: type, servings: array)
        } catch {
            let servings = try container.decode([String:[Serving]].self, forKey: .servings)
            let array = servings["serving"]!
            self.init(id: id, name: name, type: type, servings: array)
        }
    }
}

// Codable Serving struct
// Shared between the FoodMultiServing struct as well as the FoodSingleServing struct
struct Serving: Decodable {
    var calcium, calories, carbohydrate, cholesterol, fat, fiber, protein, sodium, sugar: String?
}

/////////////////////////////////////////////////////
// Custom error handling based on response error code
/////////////////////////////////////////////////////

// Codable FSError struct
// Values are set when the response is an error
struct FSError: Codable {
    let code: Int
    let message: String?
}

// RequestError enum
// Errors are thrown when the response from FatSecret consists of an error
private enum RequestError: Error {
    case InvalidKey, InvalidSignature, Unknown
}

// RequestError extension
// Sets the localized descriptions of custom errors
extension RequestError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .InvalidKey:
            return NSLocalizedString("Error: Invalid key", comment: "error")
        case .InvalidSignature:
            return NSLocalizedString("Error: Invalid signature", comment: "error")
        default:
            return NSLocalizedString("Error: Unknown", comment: "error")
        }
    }
}

/////////////////////////////////////////////////////////
// All constants that may be used for OAUTH and FatSecret
/////////////////////////////////////////////////////////
private struct Constants {
    // OAuth Parameters
    static var oAuth = ["oauth_consumer_key":"",
                        "oauth_signature_method":"HMAC-SHA1",
                        "oauth_timestamp":"",
                        "oauth_nonce":"",
                        "oauth_version":"1.0"] as Dictionary
    
    static var fatSecret = [:] as Dictionary<String, String>
    
    // Fat Secret Consumer Secret Key
    static var key = ""
    
    // Fat Secret API URL
    static let url = "http://platform.fatsecret.com/rest/server.api"
    
    // Fat Secret HTTP Request Method
    static let httpType = "POST"
}

//////////////////////////////////
// Extensions to the String object
//////////////////////////////////
private extension String {
    // String set for URL encoding process described in RFC 3986
    // Also refered to as percent encoding
    func getPercentEncodingCharacterSet() -> String {
        let digits = "0123456789"
        let lowercase = "abcdefghijklmnopqrstuvwxyz"
        let uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let reserved = "-._~"
        
        return digits + lowercase + uppercase + reserved
    }
    
    // Creates the signature string based on the consumer key and signature base string
    // Uses HMAC-SHA1 encryption
    func getSignature(key: String, params: String) -> String {
        var array = [UInt8]()
        array += params.utf8
        
        let sign = try! HMAC(key: key, variant: .sha1).authenticate(array).toBase64()!
        
        return sign
    }
    
    // Determines if string contains another string
    // Returns boolean value
    func contains(find: String) -> Bool{ return self.range(of: find) != nil }
}

/////////////////////////////////
// Extensions to the Array object
/////////////////////////////////
private extension Array {
    // Creates the parameters key, value pair array
    // Sorts the parameters, by name, using ascending byte value ordering
    var parameters: [(key: String, value: String)] {
        get{
            var array = [(key: String, value: String)]()
            
            for (key,value) in Constants.oAuth {
                array.append((key: key, value: value))
            }
            
            for (key,value) in Constants.fatSecret {
                array.append((key: key, value: value))
            }
            
            return array.sorted(by: { $0 < $1 })
        }
    }
}

////////////////////////////////////////
// Extensions to the CharacterSet object
////////////////////////////////////////
private extension CharacterSet {
    // Percent encodes string based on the URL encoding process described in RFC 3986
    // https://tools.ietf.org/html/rfc3986#section-2.4
    var percentEncoded: CharacterSet {
        get { return CharacterSet.init(charactersIn: String().getPercentEncodingCharacterSet()) }
    }
}

/////////////////////////////////////////
// Extensions to the URLComponents object
/////////////////////////////////////////
private extension URLComponents {
    // Creates URLQueryItems for URLComponent
    // Used for HTTP request
    mutating func createItemsForURLComponentsObject(array: [(key: String, value: String)]) {
        var queryItems = [URLQueryItem]()
        
        for tuple in array {
            queryItems.append(URLQueryItem(name: tuple.key, value: tuple.value))
        }
        
        self.queryItems = queryItems
    }
    
    // Returns the url parameters concatenated together
    // Parameters are seperated by '&'
    func getURLParameters() -> String {
        let queryItems = self.queryItems!
        var params = ""
        
        for item in queryItems {
            let index = queryItems.index(of: item)
            
            if index != queryItems.endIndex - 1 {
                params.append(String(describing: "\(item)&"))
            } else {
                params.append(String(describing: item))
            }
        }
        
        return params
    }
}
