//
//  MainViewController.swift
//  CoreMLSample
//
//  Created by Kostya on 18.04.2018.
//  Copyright © 2018 K.S. All rights reserved.
//

import UIKit

class StartViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet private weak var epsilan: UITextField!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.epsilan.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func startVision(_ sender: Any) {
        self.performSegue(withIdentifier: "openVisionML", sender: "vision")
    }

    @IBAction func startML(_ sender: Any) {
        self.performSegue(withIdentifier: "openVisionML", sender: "ml")
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
   
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "openVisionML") {
            let vc = segue.destination as! MainViewController
            vc.type = sender as! String
            vc.eps = self.epsilan.text
        }
    }
}
