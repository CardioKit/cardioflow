import argparse
import torch
import numpy as np
from autoencoder import AE
import coremltools as ct
from coremltools.models import datatypes
from coremltools.models.neural_network import AdamParams


def make_updatable(builder, mlmodel_url, mlmodel_updatable_path):
    """
    This method makes an existing non-updatable mlmodel updatable.
    mlmodel_url - the path the Core ML model is stored.
    mlmodel_updatable_path - the path the updatable Core ML model will be saved.
    """
    model_spec = builder.spec
    builder.make_updatable(['linear_0', 'linear_1', 'linear_2', 'linear_3'])
    builder.set_mean_squared_error_loss(name='lossLayer', input_feature=('var_22', datatypes.Array((500))))

    builder.set_adam_optimizer(AdamParams(lr=0.001, batch=32, eps=0.001))
    builder.set_epochs(allowed_set=np.linspace(1, 1000, 1000).astype(int))

    model_spec.description.trainingInput[0].shortDescription = 'Electrocardiogram representing a single heartbeat'
    model_spec.description.trainingInput[1].shortDescription = 'The same signal as the input due to the logic of an autoencoder'

    mlmodel_updatable = ct.models.MLModel(model_spec)
    mlmodel_updatable.save(mlmodel_updatable_path)
    
    return builder

def convert_model(args):
    
    model = AE()
    loss_function = torch.nn.MSELoss()
    
    optimizer = torch.optim.Adam(
        model.parameters(),
        lr=1e-2,
        weight_decay=1e-8,
    )
    
    example_input = torch.rand(20, 500) 
    traced_model = torch.jit.trace(model, example_input)
    out = traced_model(example_input)

    cModel = ct.convert(
        traced_model,
        convert_to="neuralnetwork",
        inputs=[ct.TensorType(shape=(ct.RangeDim(1, 4096), 500))]
     )

    coreml_model_path = "model_temp.mlpackage"
    cModel.save(coreml_model_path)
    spec = ct.utils.load_spec(coreml_model_path)
    builder = ct.models.neural_network.NeuralNetworkBuilder(spec=spec)

    neuralnetwork_spec = builder.spec
    neuralnetwork_spec.description.metadata.author = 'Maximilian Kapsecker'
    neuralnetwork_spec.description.metadata.license = 'MIT'
    neuralnetwork_spec.description.metadata.shortDescription = (
    		'Autoencoder for the unsupervised learning of electrocardiogram signals.'
    )

    builder = make_updatable(builder, coreml_model_path, args.dir_result)
    

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Transform PyTorch Model into CoreML.')
    parser.add_argument('--dir_result', type=str, default='../application/cardioflow/Ressources/ecgVAEC.mlmodel', help='Location of resulting CoreML model.')
    args = parser.parse_args()
    convert_model(args)
    