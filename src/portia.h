/*
*****************************************************************
portia.h

Copyright (C) 2021 Luka Micheletti
*****************************************************************
*/

#ifndef __PORTIA__
#define __PORTIA__

#include "cortex.h"
#include "utils.h"

#ifdef __CUDACC__
#include "portia_cuda.h"
#else
#include "portia_std.h"
#endif

#endif
