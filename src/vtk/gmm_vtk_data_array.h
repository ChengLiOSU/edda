// Copyright 2015 The Edda Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#ifndef GMM_VTK_ARRAY_H
#define GMM_VTK_ARRAY_H

#include <vector>
#include <stdexcept>
#include <string>

#include <vtk/vtk_common.h>

#include <distributions/gaussian_mixture.h>
#include <core/abstract_data_array.h>
#include <core/data_array.h>

namespace edda {

//---------------------------------------------------------------------------------------

/// \brief GmmVtkDataArray implements AbstractDataArray.  It holds vtkDataArrys and returns GMMs with interleaved memory accessing.
class GmmVtkDataArray: public AbstractDataArray
{
protected:
  std::vector<vtkSmartPointer<vtkDataArray> > arrays;
  size_t length = 0;
public:
  GmmVtkDataArray(vtkFieldData *fieldData, const char *arrayNamePrefix=NULL)  ;

  /// \brief Based on the input array order, assign mean0, var0, weight0, mean1, var1, weight1,...
  /// The number of arrays should be multiples of 3
  GmmVtkDataArray(std::vector<vtkSmartPointer<vtkDataArray> > arrays_);

  virtual ~GmmVtkDataArray() { }

  virtual boost::any getItem(size_t idx);

  virtual void setItem(size_t idx, const boost::any &item);

  virtual size_t getLength() { return length; }

  virtual boost::any getRawArray() { return boost::any(arrays); }
};

} // namespace edda

#endif // GMM_VTK_ARRAY_H