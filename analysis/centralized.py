import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import h5py
import pandas as pd
import numpy as np
import glob
import os
from autoencoder import AE

class HDF5Dataset(Dataset):
    def __init__(self, hdf5_file_path, split='train'):
        self.hdf5_file_path = hdf5_file_path
        self.split = split
        with h5py.File(self.hdf5_file_path, 'r') as f:
            self.length = f[f'{self.split}/matrix'].shape[0]

    def __len__(self):
        return self.length

    def __getitem__(self, idx):
        with h5py.File(self.hdf5_file_path, 'r') as h5_file:
            signal = h5_file[f'{self.split}/matrix'][idx]
            label = h5_file[f'{self.split}/annotation'][idx].decode('utf-8')
            segment = h5_file[f'{self.split}/segment'][idx].decode('utf-8')
            subject = h5_file[f'{self.split}/subject'][idx].decode('utf-8')
            signal = torch.tensor(signal, dtype=torch.float32)
            return signal, label, segment, subject

def upsample_to_length(signal, final_length):
    if final_length <= len(signal):
        return signal

    upsampled_signal = np.interp(
        np.linspace(0, len(signal) - 1, final_length),
        np.arange(len(signal)),
        signal
    )
    return upsampled_signal

def main():

    # Generate the data set as a h5 file for batch loading of the data
    # Data are preprocessed in the same manner as with the mobile on-device implementation
    window_size = 65
    final_length = 500

    devices = [f"device_{i}" for i in range(1, 21)]

    h5_file = h5py.File('data.h5', 'w')

    train_matrix_ds = h5_file.create_dataset(
        'train/matrix',
        shape=(0, final_length),
        maxshape=(None, final_length),
        chunks=True,
        dtype='float32'
    )
    train_annotation_ds = h5_file.create_dataset(
        'train/annotation',
        shape=(0,),
        maxshape=(None,),
        chunks=True,
        dtype=h5py.string_dtype(encoding='utf-8')
    )
    train_segment_ds = h5_file.create_dataset(
        'train/segment',
        shape=(0,),
        maxshape=(None,),
        chunks=True,
        dtype=h5py.string_dtype(encoding='utf-8')
    )
    train_subject_ds = h5_file.create_dataset(
        'train/subject',
        shape=(0,),
        maxshape=(None,),
        chunks=True,
        dtype=h5py.string_dtype(encoding='utf-8')
    )

    test_matrix_ds = h5_file.create_dataset(
        'test/matrix',
        shape=(0, final_length),
        maxshape=(None, final_length),
        chunks=True,
        dtype='float32'
    )
    test_annotation_ds = h5_file.create_dataset(
        'test/annotation',
        shape=(0,),
        maxshape=(None,),
        chunks=True,
        dtype=h5py.string_dtype(encoding='utf-8')
    )
    test_segment_ds = h5_file.create_dataset(
        'test/segment',
        shape=(0,),
        maxshape=(None,),
        chunks=True,
        dtype=h5py.string_dtype(encoding='utf-8')
    )
    test_subject_ds = h5_file.create_dataset(
        'test/subject',
        shape=(0,),
        maxshape=(None,),
        chunks=True,
        dtype=h5py.string_dtype(encoding='utf-8')
    )

    train_count = 0
    test_count = 0

    for device in devices:
        for k in glob.glob(f'../data/transformed_data/{device}/*.csv'):
            df = pd.read_csv(k)
            data = df['signal'].values
            annotations = df['annotation'] != "unknown"
            labels = df.loc[annotations, 'annotation'].values
            indices = df.loc[annotations].index.values

            result = []
            label = []
            d = []

            for n, idx in enumerate(indices):
                start = idx - window_size
                end = idx + window_size

                if start >= 0 and end <= len(data):
                    signal = data[start:end]
                    signal = upsample_to_length(signal, final_length)
                    signal = (signal - np.min(signal)) / (np.max(signal) - np.min(signal) + 1e-8)
                    result.append(signal.astype('float32'))
                    label.append(labels[n])
                    d.append(device)

            result = np.array(result)
            label = np.array(label, dtype='S')
            d = np.array(d, dtype='S')

            filename = os.path.basename(k)
            base_filename = filename.rsplit('.', 1)[0]
            segment_file = base_filename.rsplit('_', 1)[1]
            if segment_file == "0":
                # Test set
                n_samples = result.shape[0]
                if n_samples > 0:
                    # Resize datasets
                    test_matrix_ds.resize((test_count + n_samples, final_length))
                    test_annotation_ds.resize((test_count + n_samples,))
                    test_segment_ds.resize((test_count + n_samples,))
                    test_subject_ds.resize((test_count + n_samples,))

                    # Write data
                    test_matrix_ds[test_count:test_count + n_samples] = result
                    test_annotation_ds[test_count:test_count + n_samples] = label
                    test_segment_ds[test_count:test_count + n_samples] = segment_file
                    test_subject_ds[test_count:test_count + n_samples] = d

                    test_count += n_samples
            else:
                # Train set
                n_samples = result.shape[0]
                if n_samples > 0:
                    # Resize datasets
                    train_matrix_ds.resize((train_count + n_samples, final_length))
                    train_annotation_ds.resize((train_count + n_samples,))
                    train_segment_ds.resize((train_count + n_samples,))
                    train_subject_ds.resize((train_count + n_samples,))

                    # Write data
                    train_matrix_ds[train_count:train_count + n_samples] = result
                    train_annotation_ds[train_count:train_count + n_samples] = label
                    train_segment_ds[train_count:train_count + n_samples] = segment_file
                    train_subject_ds[train_count:train_count + n_samples] = d

                    train_count += n_samples

    h5_file.close()

    # Create dataset and dataloader for training data
    train_dataset = HDF5Dataset('data.h5', split='train')
    train_loader = DataLoader(train_dataset, batch_size=256, shuffle=True, num_workers=4)

    # Create dataset and dataloader for test data
    test_dataset = HDF5Dataset('data.h5', split='test')
    test_loader = DataLoader(test_dataset, batch_size=256, shuffle=False, num_workers=4)

    model = AE()
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")
    model = model.to(device)

    criterion = nn.MSELoss()
    optimizer = optim.Adam(
        model.parameters(),
        lr=1e-2,
        weight_decay=1e-8,
    )

    epochs = 250
    model.train()

    for epoch in range(epochs):
        epoch_loss = 0.0
        for batch in train_loader:
            inputs = batch[0].to(device)
            _, outputs = model(inputs)
            loss = criterion(outputs, inputs)

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            epoch_loss += loss.item()

        print(f"Epoch {epoch + 1}/{epochs}, Loss: {epoch_loss / len(train_loader):.4f}")

    torch.save(model, './results/model_centralized.pt')
    model.eval()

    result_dataframes = []

    with torch.no_grad():
        for loader in [test_loader, train_loader]:
            embeddings = []
            reconstruction_maes = []
            subjects = []
            segments = []
            annotations = []
            for batch in loader:
                signal = batch[0].to(device)
                embedding, reconstruction = model(signal)
                reconstruction_mae = torch.mean(torch.abs(reconstruction - signal), dim=1).cpu().numpy()
                embeddings.append(embedding.cpu().numpy())
                reconstruction_maes.append(reconstruction_mae)
                annotations.extend(batch[1])
                segments.extend(batch[2])
                subjects.extend(batch[3])

            embeddings = np.concatenate(embeddings, axis=0)
            reconstruction_maes = np.concatenate(reconstruction_maes, axis=0)
            annotations = np.array(annotations)
            segments = np.array(segments)
            subjects = np.array(subjects)

            df = pd.DataFrame({
                'subject': subjects,
                'segment': segments,
                'groundtruth': annotations,
                'residual': reconstruction_maes,
            })
            # Add embeddings as separate columns
            embedding_df = pd.DataFrame(embeddings, columns=[f'embedding_{i}' for i in range(embeddings.shape[1])])
            df = pd.concat([df.reset_index(drop=True), embedding_df.reset_index(drop=True)], axis=1)

            result_dataframes.append(df)

    df = pd.concat(result_dataframes)
    df = df.reset_index(drop=True)
    os.makedirs('./results/centralized/', exist_ok=True)
    df.to_csv('./results/centralized/all.csv', index=False)

if __name__ == '__main__':
    main()