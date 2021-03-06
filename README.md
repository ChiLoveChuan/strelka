Strelka2 Small Variant Caller
============================

Strelka calls somatic and germline small variants from mapped sequencing reads. It is optimized for rapid clinical analysis of somatic variation in tumor/normal sample pairs and germline variation in small cohorts. For best indel performance, Strelka is designed to be run with the [Manta structural variant and indel caller][manta], which provides additional sample-specific indel candidates up to Strelka's configured maxiumum indel size (by default this is 50). By design, Manta and Strelka together provide complete coverage over all indel sizes (in additional to all SVs and SNVs) for clinical somatic and germline analysis scenarios.
Strelka accepts input read mappings from BAM or CRAM
files and input alleles from VCF. It reports all small variant predictions in VCF 4.1 format. Germline variant reporting
uses the [gVCF conventions][gvcfPage] to represent both variant and reference
call confidence. See the [user guide] [UserGuide] for a full description of capabilities and limitations.

[manta]:https://github.com/Illumina/manta
[gvcfPage]:https://sites.google.com/site/gvcftools/home/about-gvcf
[UserGuide]:docs/userGuide/README.md

Methods and benchmarking details for the original version of Strelka's somatic caller are described in:

Saunders, C.T. *et al.* (2012) Strelka: Accurate somatic small-variant calling from sequenced tumor-normal sample pairs. *Bioinformatics*,
28, 1811-1817. [doi:10.1093/bioinformatics/bts271][bpaper]

Note that the somatic calling model in Strelka2 has been extensively updated since this time. An updated publication is in progress.

[bpaper]:https://dx.doi.org/10.1093/bioinformatics/bts271


License
-------

Strelka source code is provided under the [GPLv3 license] (LICENSE.txt).
Strelka includes several third party packages provided under other
open source licenses, please see [COPYRIGHT.txt] (COPYRIGHT.txt)
for additional details.


Getting Started
---------------

For Linux users, it is recommended to start from the most recent
[binary distribution on the Strelka releases page] [releases], this
distribution can be unpacked, moved to any convenient directory and
tested by [running a small demo](docs/userGuide/installation.md#demo)
included with the release distribution. Strelka can also be installed
and run on OS X. Please see the [installation instructions](docs/userGuide/installation.md)
for full build and installation details of all supported cases.

[releases]:https://github.com/Illumina/strelka/releases


Data Analysis and Interpretation
--------------------------------

After completing installation, see the [Strelka user guide] [UserGuide]
for instructions on how to run Strelka, interpret results and estimate
hardware requirements/compute cost, in addition to a high-level methods
overview.


Strelka Code Development
------------------------

For strelka code development and debugging details, see the
[Strelka developer guide] [DeveloperGuide]. This includes details
on Strelka's development protocols, special build instructions,
recommended workflows for investigating
calls, and internal documentation details.

[DeveloperGuide]:docs/developerGuide/README.md
