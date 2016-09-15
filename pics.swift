//
//  pics.swift
//  imgPics
//
//  Created by Saibersys on 9/11/16.
//  Copyright © 2016 Saibersys. All rights reserved.
//

import UIKit

class pics: UIView {
    override func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        CGContextSetLineWidth(context, 3.0)
        
        let subbu = UIImage(named: "trip.png")
        /*
        //Draw normal image
        let location = CGPointMake(25, 25)
        subbu?.drawAtPoint(location)
        */
        
        //full screen
        let entireScreen = UIScreen.mainScreen().bounds
        subbu?.drawInRect(entireScreen)
    }

}
