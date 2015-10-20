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

#include "blt_util/qscore_cache.hh"

#include <cmath>

#include <algorithm>
#include <limits>


//
inline
int
char_to_qval(const char c)
{
    return (static_cast<int>(c)-64);
}

template <typename FloatType>
FloatType
error_prob_to_phred(const FloatType prob)
{
    static const FloatType minlog10(static_cast<FloatType>(std::numeric_limits<FloatType>::min_exponent10));
    return -10.*std::max(minlog10,std::log10(prob));
}

template <typename FloatType>
FloatType
ln_error_prob_to_phred(const FloatType lnProb)
{
    static const FloatType minlog10(static_cast<FloatType>(std::numeric_limits<FloatType>::min_exponent10));
    static const FloatType ln10(std::log(static_cast<FloatType>(10)));
    return -10.*std::max(minlog10,lnProb/ln10);
}

template <typename FloatType>
int
error_prob_to_qphred(const FloatType prob)
{
    return static_cast<int>(std::floor(error_prob_to_phred(prob)+0.5));
}

template <typename FloatType>
int
ln_error_prob_to_qphred(const FloatType lnProb)
{
    return static_cast<int>(std::floor(ln_error_prob_to_phred(lnProb)+0.5));
}

inline
double
phred_to_error_prob(const double val)
{
    return std::pow(10.,-val/10.);
}

inline
double
qphred_to_error_prob(const int qscore)
{
    return qphred_cache::get_error_prob(qscore);
}

inline
double
qphred_to_ln_comp_error_prob(const int qscore)
{
    return qphred_cache::get_ln_comp_error_prob(qscore);
}

inline
double
qphred_to_ln_error_prob(const int qscore)
{
    return qphred_cache::get_ln_error_prob(qscore);
}


// modify basecall error_prob score according to mapping quality of the
// read:
inline
double
phred_to_mapped_error_prob(const double basecall_val,
                           const double mapping_val)
{
    const double be(phred_to_error_prob(basecall_val));
    const double me(phred_to_error_prob(mapping_val));
    return ((1.-me)*be)+(me*0.75);
}

inline
int
qphred_to_mapped_qphred(const int basecall_val,
                        const int mapping_val)
{
    return qphred_cache::get_mapped_qscore(basecall_val,mapping_val);
}

