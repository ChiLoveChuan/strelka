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

#include "blt_util/blt_exception.hh"
#include "blt_util/log.hh"
#include "blt_util/seq_util.hh"
#include "blt_util/vcf_streamer.hh"

#include <cassert>
#include <cstdlib>
#include <sys/stat.h>

#include <iostream>
#include <set>
#include <string>



// return true only if all chromosomes in the bcf/vcf exist in the
// bam header
static
void
check_bam_bcf_header_compatability(
    const char* bcf_filename,
    const bcf_hdr_t* bcfh,
    const bam_header_t* bamh)
{
    assert(nullptr != bamh);
    assert(nullptr != bcfh);

    // build set of chrom labels from BAM:
    std::set<std::string> bamlabels;
    for (int32_t i(0); i<bamh->n_targets; ++i)
    {
        bamlabels.insert(std::string(bamh->target_name[i]));
    }
    int n_labels(0);

    const char** bcf_labels = bcf_hdr_seqnames(bcfh, &n_labels);

    for (int i(0); i<n_labels; ++i)
    {
        if (bamlabels.find(std::string(bcf_labels[i])) != bamlabels.end()) continue;
        log_os << "ERROR: Chromosome label '" << bcf_labels[i] << "' in BCF/VCF file '" << bcf_filename << "' does not exist in the BAM header\n";
        exit(EXIT_FAILURE);
    }

    free(bcf_labels);
}



vcf_streamer::
vcf_streamer(
    const char* filename,
    const char* region,
    const bam_header_t* bh) :
    _is_record_set(false),
    _is_stream_end(false),
    _record_no(0),
    _stream_name(filename),
    _hfp(nullptr),
    _hdr(nullptr),
    _tidx(nullptr),
    _titr(nullptr),
    _kstr({0,0,0})
{
    //
    // note with the switch to samtools 0.2.X vcf/bcf still involve predominantly separate
    // apis -- no bcf support added here, but a shared function has been chosen where possible
    // ... for_instance hts_open/bcf_hdr_read should work with both vcf and bcf
    //

    if (nullptr == filename)
    {
        throw blt_exception("VCF filename is null ptr");
    }

    if (nullptr == region)
    {
        throw blt_exception("VCF region is null ptr");
    }

    if ('\0' == *filename)
    {
        throw blt_exception("VCF filename is empty string");
    }

    _hfp = hts_open(filename, "r");
    if (nullptr == _hfp)
    {
        log_os << "ERROR: Failed to open VCF file: '" << filename << "'\n";
        exit(EXIT_FAILURE);
    }

    _hdr = bcf_hdr_read(_hfp);
    if (nullptr == _hdr)
    {
        log_os << "ERROR: Failed to load header for VCF file: '" << filename << "'\n";
        exit(EXIT_FAILURE);
    }

    // read from a specific region:
    _tidx = tbx_index_load(filename);
    if (nullptr == _tidx)
    {
        log_os << "ERROR: Failed to load index for VCF file: '" << filename << "'\n";
        exit(EXIT_FAILURE);
    }

    if (nullptr != bh)
    {
        check_bam_bcf_header_compatability(filename, _hdr, bh);
    }

    // read only a region of VCF file:
    _titr = tbx_itr_querys(_tidx, region);
    if (nullptr == _titr)
    {
        _is_stream_end=true;
    }
}



vcf_streamer::
~vcf_streamer()
{
    if (nullptr != _titr) tbx_itr_destroy(_titr);
    if (nullptr != _tidx) tbx_destroy(_tidx);
    if (nullptr != _hdr) bcf_hdr_destroy(_hdr);
    if (nullptr != _hfp) hts_close(_hfp);
}



bool
vcf_streamer::
next(const bool is_indel_only)
{
    if (_is_stream_end || (nullptr==_hfp) || (nullptr==_titr)) return false;

    char*& vcf_record_string(_kstr.s);
    while (true)
    {
        if (tbx_itr_next(_hfp, _tidx, _titr, &_kstr) < 0)
        {
            _is_stream_end=true;
        }
        else
        {
            _is_stream_end=(nullptr == vcf_record_string);
        }
        _is_record_set=(! _is_stream_end);
        if (! _is_record_set) break;

        // filter out header for whole file access case:
        if (vcf_record_string[0] == '#') continue;

        _record_no++;

        if (! _vcfrec.set(vcf_record_string))
        {
            log_os << "ERROR: Can't parse vcf record: '" << vcf_record_string << "'\n";
            exit(EXIT_FAILURE);
        }
        if (! _vcfrec.is_valid()) continue;
        if (is_indel_only && (! _vcfrec.is_indel())) continue;

        break; // found expected vcf record type
    }

    return _is_record_set;
}



void
vcf_streamer::
report_state(std::ostream& os) const
{
    const vcf_record* vcfp(get_record_ptr());

    os << "\tvcf_stream_label: " << name() << "\n";
    if (NULL != vcfp)
    {
        os << "\tvcf_stream_record_no: " << record_no() << "\n"
           << "\tvcf_record: " << *(vcfp) << "\n";
    }
    else
    {
        os << "\tno vcf record currently set\n";
    }
}
