# Data

Download and transform a subset of the [Icentia11k](https://physionet.org/content/icentia11k-continuous-ecg/1.0/) dataset into the required format.

## Requirements

- install the requirements
### shfmt
    pip install -r requirements.txt

## Download and Transform

1. Create two folders: ```raw_data``` and ```data```
2. Open the terminal and run:
### shfmt
    python etl.py

The ``raw_data`` folder contains the raw signals as provided by PhysioNet, while ``transformed_data`` contains the data ready to be deployed on the mobile devices to perform federated learning experiments.
