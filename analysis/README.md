# Analysis of Results

Download and transform a subset of the [Icentia11k](https://physionet.org/content/icentia11k-continuous-ecg/1.0/) dataset into the required format.

## Requirements

- install the requirements
### shfmt
    pip install -r requirements.txt

## Run Analysis

1. Export the results from the mobile devices to this location, e.g., into a ```./results``` folder.
2. Optional: To compare with a centralized approach, please run the ```./centralized.py``` script first. The results (embeddings, residuals, and centrally trained model) will be saved in ```./results/centralized/```. Note that this requires the transformed data – the same data deployed to the mobile devices – to be available in the ```./data/transformed_data/``` directory.
3. Open the jupyter notebook ```./results.ipynb```
### shfmt
    jupyter-lab
4. Run the notebook step by step to gain insights into the performance of the approach. The results are stored in a ```media`` folder inside this folder and must be created beforehand.
