# Machine Learning Model

Define the autoencoder model as a PyTorch model and transform it into a [CoreML](https://developer.apple.com/documentation/coreml) model using [coremltools](https://apple.github.io/coremltools/docs-guides/).

## Requirements

- install the requirements
### shfmt
    pip install -r requirements.txt

## Generate the Model

Open the terminal and run:
### shfmt
    python generate_model.py

The CoreML model is per default saved to the required location, that is [../application/cardioflow/Ressources](../application/cardioflow/Ressources),
