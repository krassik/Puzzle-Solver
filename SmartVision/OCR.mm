#include "OCR.h"

#include <fstream>
#include <iostream>
#include <opencv2/opencv.hpp>

using namespace std;
using namespace cv;

//Construct an OCR object with a given number of ANNs
OCR::OCR(int numAnns, bool loadAnns)
{
    numOfAnns = numAnns;
    if(loadAnns)
        LoadANN();
}

//Destructor
OCR::~OCR()
{
    ocr_nn.clear();
}

//Load training data
void OCR::LoadData(vector<DataItem>& dataset,
                   std::string images_filename,
                   std::string labels_filename)
{
    ifstream images, labels;
    images.open (images_filename.c_str(), ios::binary);
    labels.open (labels_filename.c_str(), ios::binary);
    vector<double> input, output;

    if(!images.is_open() || !labels.is_open())
    {
        cout << "Could not open the images and/or labels files." << endl;
        return;
    }

    char* memblock = new char[16];
    unsigned char* buffer = (unsigned char*)memblock;

    //Read images parameters
    images.read(memblock, 16);
    int magic_number = (buffer[2] << 8) | buffer[3];
    int num_images = (buffer[6] << 8) | buffer[7];
    int image_h = (buffer[10] << 8) | buffer[11];
    int image_w = (buffer[14] << 8) | buffer[15];

    //Read lables parameters
    labels.read(memblock, 8);
    magic_number = (buffer[2] << 8) | buffer[3];
    int num_labels = (buffer[6] << 8) | buffer[7];

    //The number of labels must be equal to the
    //number of test data inputs.
    if(num_labels != num_images)
    {
        std::cout << "Invalid pair of files" << std::endl;
        return;
    }

    //Construct the DataItem vector
    Mat digit(image_w, image_h, CV_8UC1);
    for(int i = 0; i < num_images; i++)
    {
        //Fill in the input
        input.clear();
        for(int j = 0; j < image_h * image_w; j++)
        {
            images.read(memblock, 1);
            input.push_back((memblock[0] > 128) ? 1 : 0);
            digit.at<unsigned char>(j / image_w, j % image_w) = memblock[0];
        }

        //Fill in the output
        output.clear();
        labels.read(memblock, 1);
        for(int j = 0; j < 10; j++)
        {
            if(j == memblock[0])
            {
                output.push_back(1);
            }
            else
            {
                output.push_back(0);
            }
        }

        dataset.push_back(DataItem(input, output));

        //Verbose debug info
        //cout << (int)memblock[0] << "    ";
        //for(int k = 0; k < output.size(); k++) cout << output[k] << " ";
        //cout << endl;
        //imshow("Digit", digit);
        //waitKey(-1);
    }
    images.close();
    labels.close();
}

//Learn the train data
void OCR::TrainANN(std::string images_filename,
                   std::string labels_filename)
{
    vector<DataItem> train;
    LoadData(train, images_filename, labels_filename);
    std::cout << "Train data initialized." << std::endl;

    vector<int> neuronNumbers;
    neuronNumbers.push_back(300);// first layer has 2 neurons
    neuronNumbers.push_back(10); // second layer has 1 neuron

    for(int i = 0; i < numOfAnns; i++)
    {
        stringstream str;
        str << "ocr_problem_" << i << ".txt";

        NeuralNetwork ocr_nn = NeuralNetwork(train[0].input.size(),
                                             neuronNumbers);

        ocr_nn.Train(train, MIN_TRAIN_ERROR, MAX_TRAIN_EPOCHS);
        ocr_nn.Save(str.str().c_str());
    }

    return;
}

//Load ANNs from file
void OCR::LoadANN()
{
    ocr_nn.resize(numOfAnns);
    std::cout << "Loading networks... ";
    for(unsigned int i = 0; i < ocr_nn.size(); i++)
    {
        std::cout << i + 1 << " ";
/*
        std::stringstream str;
        str << "./anns/ocr_problem_" << i << ".txt";
        ocr_nn[i] = new NeuralNetwork(str.str().c_str());
*/
        
        NSString *pathToFile = [[NSBundle mainBundle]
            pathForResource:[NSString stringWithFormat:@"ocr_problem_%d",i]
                     ofType:@"txt"];
  /*
        NSString *str = [NSString stringWithContentsOfFile:pathToFile
                                                  encoding:NSASCIIStringEncoding
                                                     error:nil];
  */
        ocr_nn[i] = new NeuralNetwork(  [pathToFile cStringUsingEncoding:NSASCIIStringEncoding]  );
        
    }
    cout << std::endl;
}

//Recognize the input digit
int OCR::RecognizeDigit(const cv::Mat& digit)
{
    vector<double> input, output;
    input.clear();
    bool empty = true;

    //Create the input vector
    for(int i = 0; i < digit.rows; i++)
    {
        for(int j = 0; j < digit.cols; j++)
        {
            if(digit.at<unsigned char>(i, j) != 0)
            {
                input.push_back(1);
                empty = false;
            }
            else
            {
                input.push_back(0);
            }
        }
    }

    if(empty) return -1;

    //Calculate the output
    vector<int> digit_bins(10, 0);
    for(unsigned int n = 0; n < ocr_nn.size(); n++)
    {
        output.clear();
        ocr_nn[n]->Calculate(input, output);

        //Find the neuron with max activation value
        int d = max_element(output.begin(),
                            output.end()) -
                output.begin();

        digit_bins[d]++;
    }

    //Find the digit with the most votes
    int result = max_element(digit_bins.begin(),
                             digit_bins.end()) -
                 digit_bins.begin();

    return result;
}
