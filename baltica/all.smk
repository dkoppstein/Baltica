comp = config["contrasts"].keys()
workdir: config["path"]
config_path = config["config_path"]
baltica_path = config["baltica_path"]
from pathlib import Path
parent_path = Path(baltica_path).parent


module qc:
    snakefile:
        str(parent_path / "qc.smk")
    config: 
        config

use rule * from qc as qc_*

module junctionseq:
    snakefile:
        str(parent_path / "junctionseq.smk")
    config: 
        config

use rule * from junctionseq as junctionseq_*

module leafcutter:
    snakefile:
        str(parent_path / "leafcutter.smk")
    config: 
        config

use rule * from leafcutter as leafcutter_*

module majiq:
    snakefile:
        str(parent_path / "majiq.smk")
    config: 
        config

use rule * from majiq as majiq_*

module stringtie:
    snakefile:
        str(parent_path / "stringtie.smk")
    config: 
        config

use rule * from stringtie as stringtie_*

module rmats:
    snakefile:
        str(parent_path / "rmats.smk")
    config: 
        config

use rule * from rmats as rmats_*

module analysis:
    snakefile:
        str(parent_path / "analysis.smk")
    config: 
        config

use rule * from analysis as analysis_*

ruleorder: analysis_parse_rmats > rmats_rmats_create_input > qc_symlink > junctionseq_symlink > leafcutter_symlink > majiq_symlink > stringtie_symlink > rmats_symlink

localrules:
    rmats_rmats_create_input,
    junctionseq_cat_decoder,
    junctionseq_create_decoder,
    leafcutter_leafcutter_concatenate,
    majiq_majiq_create_ini, 
    qc_symlink,
    junctionseq_symlink,
    leafcutter_symlink, 
    majiq_symlink,
    stringtie_symlink,
    rmats_symlink

rule final:
    input:
        expand("majiq/voila/{comp}_voila.tsv", comp=comp),
        expand("rmats/{comp}/", comp=comp),
        expand("leafcutter/{comp}/{comp}_cluster_significance.txt", comp=comp),
        expand("junctionseq/analysis/{comp}_sigGenes.results.txt.gz", comp=comp),
        "stringtie/merged/merged.combined.gtf",
        expand(
            "results/baltica_report{project_title}.html", 
            project_title="_" + config.get("project_title", "").replace(' ', '_')),
        expand(
            "results/baltica_table{project_title}.xlsx", 
            project_title="_" + config.get("project_title", "").replace(' ', '_'))
