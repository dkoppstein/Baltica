sample_path = config["sample_path"]
name = config["samples"].keys()
sample = config["samples"].values()

from os import symlink, path
from shutil import copy2

# correct path if ends in / or not
sample_path = str(Path(sample_path) / "{sample}")

rule symlink:
    input:
        bam=expand(sample_path, sample=sample),
        bai=expand(sample_path, sample=sample)
    output:
        bam=expand('mappings/{name}.bam', name=name),
        bai=expand('mappings/{name}.bam.bai', name=name)
    run:
        for bam_in, bai_in, bam_out, bai_out in zip(
                input.bam, input.bai, output.bam, output.bai):
            symlink(bam_in, bam_out)
            symlink(bai_in, bai_out)
