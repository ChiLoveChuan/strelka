// -*- mode: c++; indent-tabs-mode: nil; -*-
//
// Manta - Structural Variant and Indel Caller
// Copyright (c) 2013-2016 Illumina, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//

///
/// \author Chris Saunders
///

#include "EstimateParametersFromErrorCounts.hh"
#include "EPECOptions.hh"
#include "errorAnalysis/SequenceErrorCounts.hh"

#include "model1.hh"
#include "modelVariantAndIndyError.hh"
#include "modelVariantAndTriggerMixError.hh"



static
void
runEPEC(
    const EPECOptions& opt)
{
    SequenceErrorCounts counts;
    counts.load(opt.countsFilename.c_str());

//    model1(counts);
//    modelVariantAndIndyError(counts);
    modelVariantAndTriggerMixError(counts);
}



void
EstimateParametersFromErrorCounts::
runInternal(int argc, char* argv[]) const
{
    EPECOptions opt;

    parseEPECOptions(*this,argc,argv,opt);
    runEPEC(opt);
}
