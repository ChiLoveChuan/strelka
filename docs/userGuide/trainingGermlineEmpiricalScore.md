# Germline Empirical Variant Score (EVS) Model Training

[User Guide Home](README.md)

## Table of Contents
[] (BEGIN automated TOC section, any edits will be overwritten on next source refresh)
* [Introduction](#introduction)
* [Requirements](#requirements)
* [Step 1: Build snv and indel training data sets](#step-1-build-snv-and-indel-training-data-sets)
  * [Step 1a: Preliminary filtering of the VCF file](#step-1a-preliminary-filtering-of-the-vcf-file)
  * [Step 1b: Assigning truth labels using hap.py](#step-1b-assigning-truth-labels-using-happy)
  * [Step 1c: Convert the annotated variant output into a CSV feature file](#step-1c-convert-the-annotated-variant-output-into-a-csv-feature-file)
  * [Step 1d (optional): Handle multiple training data sets](#step-1d-optional-handle-multiple-training-data-sets)
* [Step 2: Training an EVS model](#step-2-training-an-evs-model)
* [Step 3: Calculate Scores](#step-3-calculate-scores)
* [Step 4: Evaluate Precision / Recall for the model](#step-4-evaluate-precision--recall-for-the-model)
* [Step 5: Export the model for use in Strelka](#step-5-export-the-model-for-use-in-strelka)
[] (END automated TOC section, any edits will be overwritten on next source refresh)

## Introduction

This document outlines the Empirical Variant Score (EVS) model training process for Strelka germline variants. This is
the same method used to train the default SNV and indel EVS re-scoring models which come with Strelka, although the
speicic training and truth data sets shown here are just small examples provided for demonstration purposes.

## Requirements

Strelka germline EVS training has additional dependencies which are not included
in the primary build system. All packages required to retrain the EVS model and
run the steps in this guide are provided in the [training environment Dockerfile]
(trainingSomaticEmpiricalScore/Dockerfile) (shared with the somatic EVS training procedure),
which can be used to either setup an EVS training docker image or as a guideline to install
dependencies on another system.

## Step 1: Build snv and indel training data sets

For EVS training, the strelka workflow must be configured with the optional
`--reportEVSFeatures` argument. This will add a new VCF INFO field called `EVSF`
to both SNV and indel VCF outputs. All current EVS features used in Strelka's scoring
model in addition to various experimental features will be reported. Note that EVS
features can be reported even when scoring itself is turned off with the `--disableEVS` option
(recommended to avoid using previous EVS output for training a new EVS model).

Given a strelka gVCF genome.vcf.gz and a corresponding platinum genomes truth vcf with a bed file specifying confident regions, the following steps will produce two CSV feature files suitable for EVS training/testing of the snv and indel models.

### Step 1a: Preliminary filtering of the VCF file

First we need to filter out some unwanted gVCF entries. The following extracts the list of scoring features for use in Step 1c and removes the following:

1. off-target entries (in exome data)
2. entries that have been flagged with any type of conflict
3. entries that do not have diploid genotype (i.e. hemizygotes)

```bash
gzip -dc genome.vcf.gz |\
python ${STRELKA_INSTALL_PATH}/share/scoringModelTraining/germline/bin/filterTrainingVcf.py |\
${STRELKA_INSTALL_PATH}/libexec/bgzip -cf >|\
filtered.vcf.gz

gzip -dc filtered.vcf.gz | awk '/^#/ && /scoring_features/' >| scoringFeatures.txt
```

### Step 1b: Assigning truth labels using hap.py

Next, the haplotype comparison tool [hap.py](https://github.com/Illumina/hap.py) is used to assign training labels to
the strelka output. The truth set will be used to label strelka calls as true positive (TP) or false positive (FP), and
if confident regions are provided to the labeling schme, then calls in non-confident regions will be labeled as unknown
(UNK). False negatives are disregarded in the subsequent training steps. In the example below the
[Platinum Genomes](http://www.illumina.com/platinumgenomes/)
truth set is used to label the variant calling output. For NA12878/hg19 these truth data could
be obtained from ftp as follows:

```bash
wget ftp://platgene_ro:@ussd-ftp.illumina.com/2016-1.0/hg19/small_variants/NA12878/NA12878.vcf.gz
wget ftp://platgene_ro:@ussd-ftp.illumina.com/2016-1.0/hg19/small_variants/ConfidentRegions.bed.gz
```

Using this truth set, the following is an example hap.py command-line for a 40 core cluster producing appropriately
labeled output:

```bash
hap.py NA12878.vcf.gz filtered.vcf.gz -f ConfidentRegions.bed.gz -o happy_PG_annotated -V --preserve-info --threads 40 -P
```

### Step 1c: Convert the annotated variant output into a CSV feature file

The annotated hap.py output is next converted to a pair of csv files respectively containing features for snv and
indel calls. The example command-line:


```
gzip -dc happy_PG_annotated.vcf.gz |\
python ${STRELKA_INSTALL_PATH}/share/scoringModelTraining/germline/bin/parseAnnotatedTrainingVcf.py \
    --scoringFeatures scoringFeatures.txt \
    --snvOutput snv_training_data.csv \
    --indelOutput indel_training_data.csv
```

...generates the labeled snv and indel feature files `snv_training_data.csv` and `indel_training_data.csv` for use in
subsequent training steps.

### Step 1d (optional): Handle multiple training data sets

If multiple vcfs are to be combined for training/testing, process each
VCF to a labeled CSV feature file using the procedure described above. These training data may
be combined as required for the model learning and/or evaluation procedures described below.


## Step 2: Training an EVS model

The next step is to train a model given one or more labeled feature datasets produced in Step 1.
An example is shown below; the `--features` argument below must by germline.snv or germline.indel for snv and indel features respectively. Specifying the --ambig argument (recommended) causes unkown calls (i.e. calls in ambiguous regions) to be used as negative examples; leaving it off will avoid using unknown calls.

```
python ${STRELKA_INSTALL_PATH}/share/scoringModelTraining/germline/bin/evs_learn.py \
    --features germline.snv \
    --ambig \
    --model strelka.rf \
    --output snv_model.pickle \
    snv_training_data.csv
```

=>

```
Reading snv_training_data.csv
building tree 1 of 50
...
building tree 50 of 50
Feature ranking:
1. feature 7:SampleUsedDepthFraction (0.452272 +- 0.000716)
2. feature 6:RelativeTotalLocusDepth (0.299713 +- 0.000792)
3. feature 8:ConservativeGenotypeQuality (0.134600 +- 0.000876)
4. feature 1:SampleRMSMappingQuality (0.037543 +- 0.000379)
5. feature 2:SiteHomopolymerLength (0.031712 +- 0.000416)
6. feature 3:SampleStrandBias (0.016012 +- 0.000521)
7. feature 0:GenotypeCategory (0.014921 +- 0.000669)
8. feature 4:SampleRMSMappingQualityRankSum (0.010185 +- 0.000514)
9. feature 5:SampleReadPosRankSum (0.003041 +- 0.000232)
```

## Step 3: Calculate Scores

Given a trained model any labeled testing data can be scored.

```
python ${STRELKA_INSTALL_PATH}/share/scoringModelTraining/germline/bin/evs_evaluate.py \
    --features germline.snv \
    --classifier snv_model.pickle \
    --output snv_classified.csv \
    snv_test_data.csv
```

=>

```
Reading snv_test_data.csv
ptag      FP       TP
tag
FP      7524     4652
TP     17635  1920627
UNK   121596    54937
```

## Step 4: Evaluate Precision / Recall for the model

Any scored test data output can be further processed to evaluate precision / recall as
follows:

```
python ${STRELKA_INSTALL_PATH}/share/scoringModelTraining/germline/bin/evs_pr.py \
     --N 100 \
     --output snv_precisionrecall.csv \
     snv_classified.csv
```

=>

```
Reading snv_classified.csv
Processed 10 / 100 qual values for qual
...
Processed 100 / 100 qual values for qual
```

We can look at the result e.g. using R:

```R
data = read.csv('snv_precisionrecall.csv')
head(data)
```

=>

```
  X field      qual      tp   fp     fn tp_filtered fp_filtered     na
1 0  qual 0.3460096 1928415 6076   9847        9847        6100  68868
2 1  qual 0.1508784 1935279 8362   2983        2983        3814  98211
3 2  qual 0.1150540 1936334 9213   1928        1928        2963 107510
4 3  qual 0.7410711 1898631 3456  39631       39631        8720  37226
5 4  qual 0.9300044 1806764 2069 131498      131498       10107  16868
6 5  qual 0.8391139 1870848 2878  67414       67414        9298  27255
  na_filtered precision    recall      fracNA
1      107665 0.9968591 0.9949197 0.034376265
2       78322 0.9956978 0.9984610 0.048098981
3       69023 0.9952646 0.9990053 0.052365814
4      139307 0.9981830 0.9795533 0.019195457
5      159665 0.9988562 0.9321567 0.009239191
6      149278 0.9984640 0.9652194 0.014337334
```

... or make a plot like this:

```R
library(ggplot2)
ggplot(data, aes(x=recall, y=precision, color=field)) +
    geom_point() + theme_bw()
ggsave("snv.png", width=4, height=3, dpi=120)
```

![PR curve](trainingGermlineEmpiricalScore/snv.png)

## Step 5: Export the model for use in Strelka

Strelka uses models in JSON format, which can be produced from the model pickle file as follows:

```
python ${STRELKA_INSTALL_PATH}/share/scoringModelTraining/germline/bin/evs_exportmodel.py \
    --classifier snv_training_model.pickle \
    --output snv_training_model.json
```

Note that if the model's feature set has been changed, additional steps are required to use this file in Strelka.
This operation is outside of user guide scope at present.
