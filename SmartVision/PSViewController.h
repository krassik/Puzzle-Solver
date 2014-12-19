//
//  PSViewController.h
//  SmartVision
//
//  Created by krassik on 12/26/12.
//  Copyright (c) 2012 PS. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PSViewController : UIViewController {
    
    __weak IBOutlet UIActivityIndicatorView *activityIndicator;
}

@property (weak, nonatomic) IBOutlet UIImageView *inputImageView;
@property (weak, nonatomic) IBOutlet UIImageView *binaryImageView;

@property (weak, nonatomic) IBOutlet UIImageView *houghPlaneView;
@property (weak, nonatomic) IBOutlet UIImageView *detectedImageView;
@property (weak, nonatomic) IBOutlet UIImageView *rectifiedImageView;
@property (weak, nonatomic) IBOutlet UIImageView *cellsImageView;


@property (weak, nonatomic) IBOutlet UIImageView *outputImageView;

@end
