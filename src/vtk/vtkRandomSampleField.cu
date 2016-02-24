#include <iostream>

#include "vtkRandomSampleField.h"

#include "common.h"
#include "vtk_common.h"
#include "vtkInformation.h"
#include "vtkInformationVector.h"
#include "vtkObjectFactory.h"
#include "vtkStreamingDemandDrivenPipeline.h"

#include "gmm_vtk_data_array.h"
#include "filters/random_sample_field.h"

using namespace std;
using namespace edda;

vtkStandardNewMacro(vtkRandomSampleField);


// Copyright 2015 The Edda Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

//----------------------------------------------------------------------------
vtkRandomSampleField::vtkRandomSampleField()
{
  this->SetNumberOfInputPorts(1);
  this->SetNumberOfOutputPorts(1);
  ResultName = "RandomSample";
  Prefix = "";
}

//----------------------------------------------------------------------------
vtkRandomSampleField::~vtkRandomSampleField()
{
}


void vtkRandomSampleField::InitializeData(vtkDataSet* input,
  vtkDataSet* output)
{
  // First, copy the input geometry to the output as a starting point
  output->CopyStructure(input);
}

void vtkRandomSampleField::SampleDataArray(shared_ptr<GmmVtkDataArray> dataArray, vtkSmartPointer<vtkFieldData> output_field)
{
  // create output array
  vsp_new(vtkFloatArray, out_vtkArray);
  out_vtkArray->SetNumberOfComponents(dataArray->getNumComponents());
  out_vtkArray->SetNumberOfTuples(dataArray->getLength());
  out_vtkArray->SetName(ResultName.c_str());

#if 1 // thrust
  shared_ptr<GmmNdArray> gmmNdArray = dataArray->genNdArray();
  thrust::device_vector<Real> out(dataArray->getLength());

  randomSampleField(gmmNdArray->begin(), gmmNdArray->end(), out.begin());

  thrust::copy(out.begin(), out.end(), (float *)out_vtkArray->GetVoidPointer(0));

#else // sequential
  float *p = (float *)out_vtkArray->GetVoidPointer(0);
  int nc = dataArray->getNumComponents();
#pragma omp parallel for
  for (size_t i=0; i<dataArray->getLength(); i++)
  {
    if (nc==1) {
      p[i*nc] = dist::getSample( dataArray->getScalar(i) );
    } else {
      std::vector< dist::Variant > v = dataArray->getVector(i);
      for (int c=0; c<nc; c++)
        p[i*nc+c] = dist::getSample( v[c] );
    }
  }
#endif

  output_field->AddArray(out_vtkArray);
}

//----------------------------------------------------------------------------
int vtkRandomSampleField::RequestData(
  vtkInformation *vtkNotUsed(request),
  vtkInformationVector **inputVector,
  vtkInformationVector *outputVector)
{
  // get the info objects
  vtkInformation *inInfo = inputVector[0]->GetInformationObject(0);
  vtkInformation *outInfo = outputVector->GetInformationObject(0);

  // get the input and output
  vtkDataSet *input = vtkDataSet::SafeDownCast(
    inInfo->Get(vtkDataObject::DATA_OBJECT()));
  vtkDataSet *output = vtkDataSet::SafeDownCast(
    outInfo->Get(vtkDataObject::DATA_OBJECT()));

  this->InitializeData(input, output);

  shared_ptr<GmmVtkDataArray> dataArray;

  // process point data
  dataArray = shared_ptr<GmmVtkDataArray>(new GmmVtkDataArray(input->GetPointData()) );
  if (dataArray->getLength() > 0) {
    this->SampleDataArray(  dataArray, output->GetPointData());

    if (dataArray->getNumComponents()==1)
      output->GetPointData()->SetActiveScalars(ResultName.c_str());
    else
      output->GetPointData()->SetActiveVectors(ResultName.c_str());
  }

  dataArray = shared_ptr<GmmVtkDataArray>(new GmmVtkDataArray(input->GetCellData()) );
  if (dataArray->getLength() > 0)
  {
    this->SampleDataArray(dataArray, output->GetCellData());
    if (dataArray->getNumComponents()==1)
      output->GetCellData()->SetActiveScalars(ResultName.c_str());
    else
      output->GetCellData()->SetActiveVectors(ResultName.c_str());
  }

  output->Modified();
  this->Modified();

  return 1;
}

//----------------------------------------------------------------------------
int vtkRandomSampleField::RequestInformation(
  vtkInformation *vtkNotUsed(request),
  vtkInformationVector **inputVector,
  vtkInformationVector *outputVector)
{
  // get the info objects
  vtkInformation *inInfo = inputVector[0]->GetInformationObject(0);
  vtkInformation *outInfo = outputVector->GetInformationObject(0);

  outInfo->Set(vtkStreamingDemandDrivenPipeline::WHOLE_EXTENT(),
               inInfo->Get(vtkStreamingDemandDrivenPipeline::WHOLE_EXTENT()),
               6);

  // Generate dummy time steps to enable flickering
  double timeStepValues[] = {0,.1,.2,.3,.4,.5,.6,.7,.8,.9};
  outInfo->Set(vtkStreamingDemandDrivenPipeline::TIME_STEPS(),
    timeStepValues, 10);

  double timeRange[2];
  timeRange[0] = 0;
  timeRange[1] = 1.;
  outInfo->Set(vtkStreamingDemandDrivenPipeline::TIME_RANGE(), timeRange, 2);

  //outInfo->Set(vtkStreamingDemandDrivenPipeline::TIME_RANGE(), timeRange, 2);
  //outInfo->Set(vtkStreamingDemandDrivenPipeline::UPDATE_TIME_STEPS(), &myRequestedTime, 1);

  this->Modified();
  return 1;
}

//----------------------------------------------------------------------------
int vtkRandomSampleField::RequestUpdateExtent(
  vtkInformation *vtkNotUsed(request),
  vtkInformationVector **inputVector,
  vtkInformationVector *outputVector)
{
  // get the info objects
  vtkInformation *inInfo = inputVector[0]->GetInformationObject(0);
  vtkInformation *outInfo = outputVector->GetInformationObject(0);

  int usePiece = 0;

  // What ever happened to CopyUpdateExtent in vtkDataObject?
  // Copying both piece and extent could be bad.  Setting the piece
  // of a structured data set will affect the extent.
  vtkDataObject* output = outInfo->Get(vtkDataObject::DATA_OBJECT());
  if (output &&
      (!strcmp(output->GetClassName(), "vtkUnstructuredGrid") ||
       !strcmp(output->GetClassName(), "vtkPolyData")))
    {
    usePiece = 1;
    }

  inInfo->Set(vtkStreamingDemandDrivenPipeline::EXACT_EXTENT(), 1);

    inInfo->Set(
      vtkStreamingDemandDrivenPipeline::UPDATE_EXTENT(),
      outInfo->Get(vtkStreamingDemandDrivenPipeline::UPDATE_EXTENT()), 6);

    this->Modified();

  return 1;
}

//----------------------------------------------------------------------------
void vtkRandomSampleField::PrintSelf(ostream& os, vtkIndent indent)
{
  this->Superclass::PrintSelf(os,indent);
}
