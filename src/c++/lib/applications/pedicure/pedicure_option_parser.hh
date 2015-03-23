// -*- mode: c++; indent-tabs-mode: nil; -*-
//
// Starka
// Copyright (c) 2009-2014 Illumina, Inc.
//
// This software is provided under the terms and conditions of the
// Illumina Open Source Software License 1.
//
// You should have received a copy of the Illumina Open Source
// Software License 1 along with this program. If not, see
// <https://github.com/sequencing/licenses/>
//

///
/// \author Chris Saunders
///

#pragma once

#include "pedicure_shared.hh"

#include "blt_util/prog_info.hh"

#include "boost/program_options.hpp"


namespace po = boost::program_options;


po::options_description
get_pedicure_option_parser(
    pedicure_options& opt);


// validate options and process any required quick consistency
// adjustments
//
void
finalize_pedicure_options(
    const prog_info& pinfo,
    const po::variables_map& vm,
    pedicure_options& opt);