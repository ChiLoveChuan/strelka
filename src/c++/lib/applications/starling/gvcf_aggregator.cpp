// -*- mode: c++; indent-tabs-mode: nil; -*-
//
// Strelka - Small Variant Caller
// Copyright (c) 2009-2016 Illumina, Inc.
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

#include "gvcf_aggregator.hh"

#include "gvcf_writer.hh"
#include "indel_overlapper.hh"
#include "variant_prefilter_stage.hh"



gvcf_aggregator::
gvcf_aggregator(
    const starling_options& opt,
    const starling_deriv_options& dopt,
    const starling_streams& streams,
    const reference_contig_segment& ref,
    const RegionTracker& nocompressRegions,
    const RegionTracker& targetedRegions,
    const std::vector<std::reference_wrapper<const pos_basecall_buffer>>& basecallBuffers)
    : _scoringModels(opt, dopt.gvcf)
{
    if (! opt.gvcf.is_gvcf_output())
        throw std::invalid_argument("gvcf_aggregator cannot be constructed with nothing to do.");

    _gvcfWriterPtr.reset(new gvcf_writer(opt, dopt, streams, ref, nocompressRegions, _scoringModels));
    std::shared_ptr<variant_pipe_stage_base> nextPipeStage(_gvcfWriterPtr);
    if (opt.is_ploidy_prior)
    {
        std::shared_ptr<variant_pipe_stage_base> overlapper(new indel_overlapper(_scoringModels, ref, nextPipeStage));
        _codonPhaserPtr.reset(new Codon_phaser(opt, basecallBuffers, overlapper));
        nextPipeStage = _codonPhaserPtr;
    }
    const bool isTargetedRegions(not opt.gvcf.targeted_regions_bedfile.empty());
    _head.reset(new variant_prefilter_stage(_scoringModels, isTargetedRegions, targetedRegions, nextPipeStage));
}

gvcf_aggregator::~gvcf_aggregator()
{
    _head->flush();
}

void
gvcf_aggregator::
add_site(std::unique_ptr<GermlineSiteLocusInfo> si)
{
    _head->process(std::move(si));
}

void
gvcf_aggregator::add_indel(std::unique_ptr<GermlineIndelLocusInfo> info)
{
    _head->process(std::move(info));
}

void gvcf_aggregator::reset()
{
    _head->flush();
}




