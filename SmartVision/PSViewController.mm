//
//  PSViewController.m
//  SmartVision
//
//  Created by krassik on 12/26/12.
//  Copyright (c) 2012 PS. All rights reserved.
//

#import "PSViewController.h"
#import "PSViewController.h"
#import "SudokuImage.h"
#import "OCR.h"
#import <opencv2/opencv.hpp>
#import "GASolver.h"

using namespace std;


@interface PSViewController ()

@end

@implementation PSViewController

- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    
    return cvMat;
}

- (cv::Mat)cvMatGrayFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC1); // 8 bits per component, 1 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    
    return cvMat;
}

-(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

void PrintRecognisedSudoku(std::vector<int> givens)
{
    for(int i = 0; i < SUDOKU_ORDER; i++)
    {
        std::cout << "|===|===|===|===|===|===|===|===|===|" << std::endl;
        std::cout << "|";
        for(int j = 0; j < SUDOKU_ORDER; j++)
        {
            if(givens[SUDOKU_ORDER * i + j] != 0)
            {
                std::cout << " " << givens[SUDOKU_ORDER * i + j] << " |";
            }
            else
            {
                std::cout << "   |";
            }
        }
        std::cout << std::endl;
    }
    std::cout << "|===|===|===|===|===|===|===|===|===|" << std::endl;
}


-(void) solveSudoku
{
    [activityIndicator startAnimating];

    
    // Do any additional setup after loading the view, typically from a nib.
    cv::Mat inputMat = [self cvMatFromUIImage:_inputImageView.image];
    
    // Initialize sudoku image
    SudokuImage sud_img(inputMat);
    
    [self.binaryImageView setImage:[self UIImageFromCVMat:sud_img.binary_image]];
    [self.houghPlaneView setImage:[self UIImageFromCVMat:sud_img.DisplayHoughPlane()]];
    [self.detectedImageView setImage:[self UIImageFromCVMat:sud_img.detected_img]];
    [self.rectifiedImageView setImage:[self UIImageFromCVMat:sud_img.rect_sudoku]];
    [self.cellsImageView setImage:[self UIImageFromCVMat:sud_img.DisplayRectifiedCells()]];
    
     // Initialize OCR
    
     OCR ocr(20);
    
    vector<int> digits;
    //Recognieze each cell's digit
    for(int i = 0; i < SUDOKU_ORDER; i++)
    {
        for(int j = 0; j < SUDOKU_ORDER; j++)
        {
            cv::Mat cell = sud_img.GetDigit(i, j, cv::Size(28, 28));
            int digit = ocr.RecognizeDigit(cell);
            if(digit != -1)
            {
                digits.push_back(digit);
            }
            else
            {
                digits.push_back(0);
            }
        }
    }
    
    
    PrintRecognisedSudoku(digits);
    Sudoku s = GASolver::Solve(digits);
    s.Print();
    
    [self.outputImageView setImage:[self UIImageFromCVMat:sud_img.DrawSolution(s)]];
    [activityIndicator stopAnimating];
}




- (void)viewDidLoad
{
    [super viewDidLoad];
    
    dispatch_queue_t queue = dispatch_queue_create("com.app.task",NULL);
    
    dispatch_async(queue,^{
        activityIndicator.hidesWhenStopped = YES;
        [self solveSudoku];
        
    });
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
