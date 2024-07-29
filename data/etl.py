import argparse
import wfdb
import pandas as pd
import numpy as np
import random
import glob
import os
import subprocess
from tqdm import tqdm

# Define a function to process each segment
def process_segment(segment, data_path, subject):
    filename = f'{data_path}/{subject}_s{segment:02d}'
    signal = wfdb.rdsamp(filename)[0][:, 0]
    annotation = wfdb.rdann(filename, 'atr')
    df = pd.DataFrame(columns=['signal', 'annotation'])

    df["signal"] = signal
    df["annotation"] = "unknown"
    df.loc[annotation.sample, "annotation"] = annotation.symbol
    # we don't want to consider the unknown and arrhythmia samples
    df.annotation = df.annotation.replace("Q", "unknown").replace("+", "unknown")
    df.annotation = df.annotation.replace("N", "normal").replace("S", "pac").replace("V", "pvc")

    return df

def process_subject(args):
    
    random.seed(args.seed)
    np.random.seed(args.seed)
    
    subjects = np.random.choice(range(0, 11000), args.samples, replace=False)
    subjects = ['p' + item.zfill(5) for item in subjects.astype(str)]

    print("The data of the following subjects are used:", subjects)

    directory = args.dir_download
    base_path = args.dir_result + "/device_"
    subjects_str=",".join(subjects)

    if args.download:
        command = f"sh download_script.sh -d {directory} -p {subjects_str}"
        result = subprocess.run(command, shell=True, capture_output=True, text=True)

    metadata = pd.DataFrame()

    # Process each subject
    for index, subject in tqdm(enumerate(subjects)):
        
        subject_path = base_path + str(index + 1) + "/"
        os.makedirs(subject_path, exist_ok=True)
        data_path = directory + subject
        
        for segment in tqdm(range(50), position=0, leave=True):
            df_segment = process_segment(segment, data_path, subject)
            if (len(df_segment.annotation.unique()) > 1):
                df_segment.to_csv(f'{subject_path}{subject}_{segment}.csv', index=False)
        
            temp_meta = pd.DataFrame(df_segment.groupby("annotation")["signal"].count()).transpose().reset_index()
            temp_meta['subject'] = f'{subject}'
            temp_meta['device'] = index + 1
            temp_meta['segment'] = segment
            temp_meta = temp_meta.drop(['index', 'unknown'], axis=1)
            metadata = pd.concat([metadata, temp_meta])
    
    metadata.to_csv(args.dir_result + '/meta_data.csv', index=False)

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Download and transform the Icentia11k dataset.')
    parser.add_argument('--samples', type=int, default=20, help='Number of samples')
    parser.add_argument('--download', type=bool, default=False, help='Download the samples')
    parser.add_argument('--seed', type=int, default=42, help='seed for random computations')
    parser.add_argument('--dir_download', type=str, default='./raw_data/', help='directory of downloaded data')
    parser.add_argument('--dir_result', type=str, default='./transformed_data/', help='directory of transformed data')
    args = parser.parse_args()
    process_subject(args)
