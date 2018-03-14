//
//  ViewController.swift
//  FatSecretSwift
//
//  Created by Nick Bellucci on 3/14/18.
//  Copyright © 2018 Nick Bellucci. All rights reserved.
//

import UIKit

struct FatSecret {
    static let apiKey = "Your API Key"
    static let apiSecret = "Your Secret Key"
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let fatSearchRequest = FatSecretAPI()
        fatSearchRequest.key = FatSecret.apiKey
        fatSearchRequest.secret = FatSecret.apiSecret
        fatSearchRequest.searchFoodBy(name: "Hotdog") { (search) in
            print(search.foods)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

