// TODO nf-core: If in doubt look at other nf-core/modules to see how we are doing things! :)
//               https://github.com/nf-core/modules/tree/master/modules/nf-core/
//               You can also ask for help via your pull request or on the #modules channel on the nf-core Slack workspace:
//               https://nf-co.re/join
// TODO nf-core: A module file SHOULD only define input and output files as command-line parameters.
//               All other parameters MUST be provided using the "task.ext" directive, see here:
//               https://www.nextflow.io/docs/latest/process.html#ext
//               where "task.ext" is a string.
//               Any parameters that need to be evaluated in the context of a particular sample
//               e.g. single-end/paired-end data MUST also be defined and evaluated appropriately.
// TODO nf-core: Software that can be piped together SHOULD be added to separate module files
//               unless there is a run-time, storage advantage in implementing in this way
//               e.g. it's ok to have a single module for bwa to output BAM instead of SAM:
//                 bwa mem | samtools view -B -T ref.fasta
// TODO nf-core: Optional inputs are not currently supported by Nextflow. However, using an empty
//               list (`[]`) instead of a file can be used to work around this issue.

process SMUDGEPLOT_ALL {
    tag "${meta.id}"
    label 'process_medium'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/67/67768ae2b68b74edaaa5132770984f2369e6e2d50595051953b87d339ecb915f/data'
        : 'community.wave.seqera.io/library/fastk_smudgeplot:31977b35fedfc753'}"

    input:
    // Input .smu file from hetmers step
    tuple val(meta), path(smu_file)

    output:
    // Output PDFs, summary tables, and logs
    tuple val(meta), path("*.pdf"), emit: pdf
    tuple val(meta), path("*.tsv"), emit: tsv, optional: true
    tuple val(meta), path("*.txt"), emit: txt, optional: true
    // TODO nf-core: List additional required output channels/values here
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    smudgeplot.py all \\
        ${args} \\
        -o ${prefix} \\
        ${smu_file}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        smudgeplot: \$(smudgeplot.py --version 2>&1 || echo "0.4.0")
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_centralities.pdf
    touch ${prefix}_smudgeplot.pdf
    touch ${prefix}_smudgeplot_log10.pdf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        smudgeplot: "0.4.0"
    END_VERSIONS
    """
}
