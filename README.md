# cardioflow
 
The aim of cardioflow is to advance research in the field of federated unsupervsied learning for the detection of anomalies in electrocardiogram signals recorded in mobile environments. The prototype application is implemented for iOS.

## Structure

The repository contains several elements and is structured as follows:
The ```src``` folder contains three subfolders with code for creating and running the overall pipeline.
cardioflow

1. src/application:
	- This folder holds the source code for the iOS application that can record and preprocess ECG signals.
	- It includes functionalities for on-device machine learning, participation in a federated learning pipeline as a client node, predicting outliers, evaluating results, and visualizing outcomes.
2. src/federated:
	- The federated folder contains code to set up a Flower server, which acts as the orchestrating server for federated learning experiments.
3. src/model:
	- The model folder includes the unsupervised autoencoder model (autoencoder.py), which can be adapted for different model designs.
	- The swift-ae.ipynb notebook loads the PyTorch implementation of the autoencoder and converts it into a CoreML model.
	- The resulting model is automatically stored in src/application/Resources/.
 	- Note: If you rename the model, ensure it is correctly referenced in your Xcode project to be copied and transferred to mobile devices as required.

4. data:
	- The data folder contains code to download parts of the Icentia11k dataset and transform them into the required format for on-device experiments.
 	- Using a seed ensures the choice of subjects is reproducible.

5. analysis:
	- The analysis folder is used to process the data exported or transmitted to an analysis computer after the experiment concludes.
	- It contains code to further analyze the experimental outcomes and render results visually for publication purposes.

## How to Use

1. Optional: Execute the script in the [data folder](./data/) to download and prepare the respective data (only required in case of reproducing the experiment)
2. Optional: Customize the coreml model to your needs by following the instructions in [src/model](src/model/)
3. Set up the application following the instructions in [src/application](src/application/)
4. Set up the federated learning server following the instructions in [src/federated](src/federated/)
5. Optional: Analyze the results of the on-device processing by transfering the data into the [analysis](./analysis/) folder.

## Remark

The application is for scientific purposes solely and is not allowed for medical diagnosis.

## How to cite?

If you are using parts of this work or build your experiments up on this repository please cite the following article:

TBD
