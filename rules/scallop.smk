# -*- coding: utf-8
"""
Created on 17:07 27/07/2018
Snakemake file for denovo transcriptomics followed by quantification
with Scallop and Salmon pipeline.
"""
__author__ = "Thiago Britto Borges"
__copyright__ = "Copyright 2019, Dieterichlab"
__email__ = "Thiago.Br§ittoBorges@uni-heidelberg.de"
__license__ = "MIT"

from itertools import groupby
from os.path import join


def rename_bam_to_fastq(x):
  # reads star log for input files
  f = x.replace("Aligned.sortedByCoord.out.bam", "Log.out")
  with open(f) as fin:
    for line in fin:
      if line.startswith("##### Command Line:"):
        line = next(fin)
        break

  for args in line.split("--"):
    if args.startswith("readFilesIn"):
      break
  return [x.split("mapping")[0] + arg for arg in args.split()[1:3]]

cond, rep = glob_wildcards("mappings/{cond}_{rep}.bam")

configfile: "config.yml"
name = config["samples"].keys()
raw_name = config["samples"].values()
sample_path = config["sample_path"]
FILES = {k: rename_bam_to_fastq(join(sample_path, v))
         for k, v in zip(name, raw_name)}


d = {k: list(v) for k, v in groupby(
    sorted(zip(cond, rep)), key=lambda x: x[0])}

cond = set(cond)

rule all:
  input:
    expand("mappings/{name}.bam", name=name),
    expand("scallop/merged_bam/{group}.bam", group=cond),
    expand("scallop/scallop/{group}.gtf", group=cond),
    expand("scallop/salmon/{sample}/quant.sf", sample=name),
    "scallop/cuffmerge/merged.fa",
    "scallop/salmon/salmon_index/",
    "scallop/salmon/quant.tsv.gz"

localrules: symlink

include: "symlink.smk"

rule merge_bam:
  input:
    lambda wc:
      ["mappings/{}_{}.bam".format(*x) for x in d[wc.group]]
  output:
    bam = "scallop/merged_bam/{group}.bam",
    bai = "scallop/merged_bam/{group}.bam.bai"
  conda:
    "../envs/scallop.yml"
  threads:
    10
  wildcard_constraints:
    group = "|".join(cond)
  shell:
    "samtools merge {output.bam} {input} --threads {threads};"
    "samtools index {output.bam} {output.bai} "


rule denovo_transcriptomics:
  input:
    "merged_bam/{group}.bam"
  output:
    "scallop/scallop/{group}.gtf"
  conda:
    "../envs/scallop.yml"
  params:
    library_type = "first"
  wildcard_constraints:
    group = "|".join(cond)
  log:
    "log/scallop_{group}.log"
  shell:
    "module load scallop; "
    "scallop -i {input} -o {output} "
    "--library_type {params.library_type} "
    "--min_flank_length 6 "
    "--min_transcript_coverage 3 "
    "--min_splice_bundary_hits 3 2> {log}"


# this step concatenates all denovo gtf to one so we can a unique index for salmon
rule merge_gtf:
  input:
    expand("scallop/scallop/{cond}.gtf", cond=cond)
  output:
    "scallop/cuffmerge/merged.gtf"
  conda:
    "../envs/scallop.yml"
  log:
    "log/cuffmerge.log"
  params:
    fasta = config["ref_fa"],
    gtf = config["ref"]
  shell:
    "cuffcompare -s {params.fasta} -GC -r {params.gtf} {params.gtf}; "
    "for i in {input}; do echo '$i' >> cuffmerge/gtf_list; done; "
    "cuffmerge -o cuffmerge/ -g {params.gtf} -s {params.fasta} "
    "--min-isoform-fraction 0.1 cuffmerge/gtf_list"


rule extract_sequences:
  input:
    rules.merge_gtf.output
  output:
    "scallop/cuffmerge/merged.fa"
  conda:
    "../envs/scallop.yml"
  log:
    "log/gffread.log"
  params:
    fasta = config["ref_fa"]
  shell:
    "gffread {input} -g {params.fasta} -w {output} 2>{log}"


rule salmon_index:
  input:
    rules.extract_sequences.output
  output:
    directory("scallop/salmon/salmon_index/")
  conda:
    "../envs/scallop.yml"
  threads:
    10
  log:
    "logs/salmon_index.log"
  shell :
    "salmon index -t {input} -i {output} -p {threads} 2> {log}"


rule salmon_quant:
  input:
    r1 = lambda wildcards: FILES[wildcards.sample][0],
    r2 = lambda wildcards: FILES[wildcards.sample][1],
    index = "scallop/salmon/salmon_index/"
  output:
    "scallop/salmon/{sample}/quant.sf",
    "scallop/salmon/{sample}/lib_format_counts.json"
  conda:
    "../envs/scallop.yml"
  threads:
    10
  log:
    "logs/{sample}_salmons_quant.log"
  shell:
    "salmon quant -p {threads} -i {input.index} "
    "--libType A "
    "-1 <(gunzip -c {input.r1}) "
    "-2 <(gunzip -c {input.r2}) "
    "-o salmon/{wildcards.sample}/ &> {log}"


rule collate_salmon:
  input:
    expand("scallop/salmon/{sample}/quant.sf",
      sample=name)
  output:
    "scallop/salmon/quant.tsv.gz"
  run:
    import gzip
    from os.path import basename, dirname

    b = lambda x: bytes(x, "UTF8")

    # Create the output file.
    with gzip.open(output[0], "wb") as out:

      # Print the header.
      header = open(input[0]).readline()
      out.write(b("sample\t" + header))

      for i in input:
        sample = basename(dirname(i))
        lines = open(i)
        # Skip the header in each file.
        lines.readline()
        for line in lines:
          out.write(b(sample + "\t" + line))