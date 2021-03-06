#
# Strelka - Small Variant Caller
# Copyright (c) 2009-2016 Illumina, Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#

"""
Workflow configuration options shared by multiple
configuration scripts.
"""

import os,sys

scriptDir=os.path.abspath(os.path.dirname(__file__))
scriptName=os.path.basename(__file__)

sys.path.append(scriptDir)

from configureOptions import ConfigureWorkflowOptions
from configureUtil import assertOptionExists, joinFile, OptParseException, \
                          validateFixExistingDirArg, validateFixExistingFileArg, \
                          checkFixTabixListOption
from workflowUtil import exeFile, parseGenomeRegion


def cleanLocals(locals_dict) :
    """
    When passed a locals() dictionary, clean out all of the hidden keys and return
    """

    return dict((k,v) for (k,v) in locals_dict.items() if not k.startswith("__") and k != "self")



class StrelkaSharedWorkflowOptionsBase(ConfigureWorkflowOptions) :

    def addWorkflowGroupOptions(self,group) :
        group.add_option("--referenceFasta",type="string",metavar="FILE",
                         help="samtools-indexed reference fasta file [required]")
        group.add_option("--indelCandidates", type="string", dest="indelCandidatesList", metavar="FILE", action="append",
                         help="Specify a VCF of candidate indel alleles. These alleles are always"
                              " evaluated but only reported in the output when they are inferred to exist in the sample."
                              " The VCF must be tabix indexed."
                              " All indel alleles must be left-shifted/normalized, any unnormalized alleles will be ignored."
                              " This option may be specified more than once, multiple input VCFs will be merged."
                              " (default: None)")
        group.add_option("--forcedGT", type="string", dest="forcedGTList", metavar="FILE", action="append",
                         help="Specify a VCF of candidate alleles. These alleles are always"
                              " evaluated and reported even if they are unlikely to exist in the sample."
                              " The VCF must be tabix indexed."
                              " All indel alleles must be left-shifted/normalized, any unnormalized allele will trigger a"
                              " a runtime error."
                              " This option may be specified more than once, multiple input VCFs will be merged."
                              " Note that for any SNVs provided in the VCF, the SNV site will be reported (and for gVCF,"
                              " excluded from block compression), but the specific SNV alleles are ignored."
                              " (default: None)")
        group.add_option("--exome", dest="isExome", action="store_true",
                         help="Set options for WES input: turn off depth filters")
        group.add_option("--runDir", type="string",metavar="DIR",
                         help="Run script and run output will be written to this directory [required] (default: %default)")

    def addExtendedGroupOptions(self,group) :
        # note undocumented library behavior: "dest" is optional, but not including it here will
        # cause the hidden option to always print
        group.add_option("--scanSizeMb", type="int", dest="scanSizeMb", metavar="INT",
                         help="Maximum sequence region size (in megabases) scanned by each task during "
                         "genome variant calling. (default: %default)")
        group.add_option("--region", type="string",dest="regionStrList",metavar="REGION", action="append",
                         help="Limit the analysis to a region of the genome for debugging purposes. "
                              "If this argument is provided multiple times all specified regions will "
                              "be analyzed together. All regions must be non-overlapping to get a "
                              "meaningful result. Examples: '--region chr20' (whole chromosome), "
                              "'--region chr2:100-2000 --region chr3:2500-3000' (two regions)'")
        group.add_option("--callMemMb",dest="callMemMbOverride",type="int",metavar="INT",
                         help="Set variant calling task memory limit (in megabytes). It is not "
                              "recommended to change the default in most cases, but this might be required "
                              "for a sample of unusual depth.")
        group.add_option("--retainTempFiles", dest="isRetainTempFiles", action="store_true",
                         help="Keep all temporary files (for workflow debugging)")
        group.add_option("--disableEVS", dest="isEVS", action="store_false",
                         help="Disable empirical variant scoring.")
        group.add_option("--reportEVSFeatures", dest="isReportEVSFeatures", action="store_true",
                         help="Report all Empirical Variant Scoring (EVS) features in VCF output.")

        ConfigureWorkflowOptions.addExtendedGroupOptions(self,group)


    def getOptionDefaults(self) :
        """
        Set option defaults.

        Every local variable in this method becomes part of the default hash
        """

        configCommandLine=sys.argv

        libexecDir=os.path.abspath(os.path.join(scriptDir,"@THIS_RELATIVE_LIBEXECDIR@"))
        assert os.path.isdir(libexecDir)

        bgzipBin=joinFile(libexecDir,exeFile("bgzip"))
        htsfileBin=joinFile(libexecDir,exeFile("htsfile"))
        samtoolsBin=joinFile(libexecDir,exeFile("samtools"))
        tabixBin=joinFile(libexecDir,exeFile("tabix"))
        bgcatBin=joinFile(libexecDir,exeFile("bgzf_cat"))

        countFastaBin=joinFile(libexecDir,exeFile("countFastaBases"))
        getChromDepthBin=joinFile(libexecDir,exeFile("GetChromDepth"))

        mergeChromDepth=joinFile(libexecDir,"mergeChromDepth.py")
        catScript=joinFile(libexecDir,"cat.py")
        vcfCmdlineSwapper=joinFile(libexecDir,"vcfCmdlineSwapper.py")

        # TODO: these aren't shared and should go into child classes:
        strelkaGermlineBin=joinFile(libexecDir,exeFile("starling2"))
        strelkaSomaticBin=joinFile(libexecDir,exeFile("strelka2"))
        strelkaPedigreeBin=joinFile(libexecDir,exeFile("pedicure"))
        statsMergeBin=joinFile(libexecDir,exeFile("MergeRunStats"))

        # default memory request per process-type
        #
        # where different values are provided for SGE and local runs note:
        #  1. for SGE the memory limits must be greater than the highest memory use ever
        #      expected in a production run. The consequence of exceeding this limit is a failed
        #      run.
        #   2. for localhost the memory usage should be at least above the highest mean memory
        #       use ever expected in a production run. The consequence of exceeding the mean is
        #       a slow run due to swapping.
        #
        callSGEMemMb=4*1024
        callLocalMemMb=2*1024


        runDir = "variantCallWorkflow"

        # extended options
        scanSizeMb = 12
        regionStrList = None
        callMemMbOverride = None

        isExome = False

        # isRNA is shared by all Strelka workflows, but only can be set for the germline calling case:
        isRNA = False

        isRetainTempFiles = False

        # Empirical Variant Scoring:
        isEVS = True
        isReportEVSFeatures = False

        indelErrorModelName = None
        inputIndelErrorModelsFile = None

        return cleanLocals(locals())



    def validateAndSanitizeExistingOptions(self,options) :

        options.runDir=os.path.abspath(options.runDir)

        options.referenceFasta=validateFixExistingFileArg(options.referenceFasta,"reference")

        # check for reference fasta index file:
        if options.referenceFasta is not None :
            faiFile=options.referenceFasta + ".fai"
            if not os.path.isfile(faiFile) :
                raise OptParseException("Can't find expected fasta index file: '%s'" % (faiFile))

        checkFixTabixListOption(options.indelCandidatesList,"candidate indel vcf")
        checkFixTabixListOption(options.forcedGTList,"forced genotype vcf")

        if (options.regionStrList is None) or (len(options.regionStrList) == 0) :
            options.genomeRegionList = None
        else :
            options.genomeRegionList = [parseGenomeRegion(rr) for r in options.regionStrList for rr in r.split("+")]


    def validateOptionExistence(self,options) :

        assertOptionExists(options.runDir,"run directory")

        assertOptionExists(options.referenceFasta,"reference fasta file")
