#include "thrust/device_vector.h"

// Compile with C++ compiler if Cuda is not used
#if THRUST_DEVICE_SYSTEM!=THRUST_DEVICE_SYSTEM_CUDA
#include "vtkUncertainIsocontour.cu"
#endif
