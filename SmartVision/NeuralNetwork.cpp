/*
 * NeuralNetwork.cpp
 *
 */

#include "NeuralNetwork.h"
#include <iostream>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <fstream>
#include <limits>

//Construct a neural network using the number of inputs
//and the number of neurons per each layer
NeuralNetwork::NeuralNetwork(int nInputs, const vector<int>& neuronsPerLayer)
{
    this->numOfLayers = neuronsPerLayer.size();
    this->numOfInputs = nInputs;

    this->layers.push_back(
        NeuralLayer(neuronsPerLayer.front(), numOfInputs));

    for(unsigned int i = 1; i < neuronsPerLayer.size(); i++)
    {
        this->layers.push_back(
            NeuralLayer(neuronsPerLayer[i],
                        neuronsPerLayer[i-1]));
    }
}

//Construct a neural network from file
NeuralNetwork::NeuralNetwork(std::string filename)
{
    Load(filename);
}

//Destructor
NeuralNetwork::~NeuralNetwork()
{
    layers.clear();
}

//Calculate the output of the network given the inputs
void NeuralNetwork::Calculate(vector<double> input, vector<double>& output)
{
    for(unsigned int i = 0; i < this->layers.size(); i++)
    {
        layers[i].Calculate(input, output);
        input = output;
    }
}

//Train the neural network
double NeuralNetwork::Train(const vector<DataItem>& data,
                            double maxError,
                            int maxIterations)
{
    double sse = 0;
    double sseMin = std::numeric_limits<double>::max();
    double sseSum = 0;
    int wellTrained = 0;
    vector<double> output;

    for(int iter = 0; iter < maxIterations; iter++)
    {
        sse = 0;
        int beg = (iter * 100) % data.size();
        int end = std::min(beg + 100, (int)data.size());

        for(int i = beg; i < end; i++)
        {
            this->Calculate(data[i].input, output);

            //calc delta last layer
            int outputSize = output.size();
            for(int j = 0; j < outputSize; j++)
            {
                double error = data[i].output[j] - output[j];
                layers.back().neurons[j].error = error;
                layers.back().neurons[j].delta = error *
                    output[j] * (1 - output[j]);
                sse += error * error;

            } // calc detla last layer

            sseSum += sse;

            for(int j = layers.size() - 2; j >= 0; j--)
            {
                unsigned int neuronsSize = layers[j].neurons.size();

                for(unsigned int n = 0; n < neuronsSize; n++)
                {
                    double error = 0;

                    unsigned int nextNeuronsSize = layers[j+1].neurons.size();
                    for(unsigned int next_n = 0; next_n < nextNeuronsSize; next_n++)
                    {
                        error += layers[j+1].neurons[next_n].delta *
                            layers[j+1].neurons[next_n].weights[n + 1];
                    }

                    layers[j].neurons[n].error = error;
                    layers[j].neurons[n].delta = error *
                        layers[j].neurons[n].output *
                        (1 - layers[j].neurons[n].output);
                } //next neuron
            } //next layer

            this->AdjustWeights();

        } //sample

        if(sse < maxError)
        {
            wellTrained++;
            if(wellTrained == 10)
            {
                std::cout << "Iterations " << iter
                    << " SSE: " << sse << std::endl;
                break;
            }
        }
        else
        {
            wellTrained = 0;
        }

        if(sse < sseMin) { sseMin = sse; }
        if(iter % 10 == 0)
        {
           std::cout << "Iterations " << iter
                << " SSE: " << sse
                << " Min: " << sseMin
                << " Average SSE: " << sseSum / 10
                << std::endl;
            sseSum = 0;
        }
    }//iter

    return sse;
}

//Adjust the weights according to the delta rule
void NeuralNetwork::AdjustWeights()
{
    double deltaWeight;

    //For each layer i
    for(int i = 0; i < layers.size(); i++)
    {
        //For each neuron j in layer i
        for(int j = 0; j < layers[i].neurons.size(); j++)
        {
            Neuron& neuron = layers[i].neurons[j];
            //For each weight k of neuron j in layer i
            for(int k = 0; k < neuron.numInputs; k++)
            {
                deltaWeight = LEARNING_RATE * neuron.delta * neuron.inputs[k] +
                    + MOMENTUM_RATE * neuron.lastWeightChanged[k];
                neuron.weights[k] += deltaWeight;
                neuron.lastWeightChanged[k] = deltaWeight;
            }
        }
    }
}

//Load the network from a file
void NeuralNetwork::Load(std::string filename)
{
    //Clean the previous instance
    layers.clear();

    std::ifstream dataFile;
    dataFile.open(filename.c_str());

    if (dataFile.is_open())
    {
        dataFile >> this->numOfInputs >> this->numOfLayers;

        vector<int>nInLayer;
        for (int i = 0; i < this->numOfLayers; i++)
        {
            int num;
            dataFile >> num;
            nInLayer.push_back(num);
        }
        nInLayer.insert(nInLayer.begin(),this->numOfInputs);
        //create a layer
        //for each layer i, layer i-1 is the number of inputs
        for (unsigned int i = 1; i < nInLayer.size(); i++)
        {
            double data;
            vector<Neuron> buildLayer(nInLayer[i]);

            for (int n = 0; n < nInLayer[i]; n++)
            {
                vector <double> nWeights(nInLayer[i-1] + 1); //+ 1 for bias
                for (int w = 0; w <= nInLayer[i-1]; w++)
                {
                    dataFile >> data;
                    nWeights[w] = data;
                }
                buildLayer[n] = Neuron(nWeights);
            }

            this->layers.push_back(NeuralLayer(buildLayer));
        }
    }
    else
    {
        std::cout << "Error openning file \"" << filename << "\"!";
        return;
    }
    dataFile.close();
}
//Save the network to a file
void NeuralNetwork::Save(std::string filename)
{
    std::ofstream dataFile;
    dataFile.open(filename.c_str());

    if (dataFile.is_open())
    {
        //Write the number of inputs and layers
        dataFile << this->numOfInputs << " " << this->numOfLayers;
        //Write the number of neurons in each layer
        for (unsigned int i=0; i<this->layers.size(); i++)
        {
            dataFile << " " << this->layers[i].neurons.size();
        }
        //Write each weight
        for (unsigned int l=0; l<this->layers.size(); l++)
        {
            for (unsigned int n=0; n<this->layers[l].neurons.size();n++)
            {
                for (int w=0; w<this->layers[l].neurons[n].numInputs; w++)
                {
                    dataFile << " " << this->layers[l].neurons[n].weights[w];
                }
            }
        }

    }
    else
    {
        std::cout << "Error openning file \"" << filename << "\"!";
        return;
    }
    dataFile.close();
}


