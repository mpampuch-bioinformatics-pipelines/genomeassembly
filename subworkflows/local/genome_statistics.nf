//
// Evaluate genome by collectings stats
//

//
// Adapted from Sanger Genomenote pipeline by @priyanka-surana
// https://github.com/sanger-tol/genomenote/blob/383f23e6b7a89f9aad6b85c8f7320b5c5825de73/subworkflows/local/genome_statistics.nf
//

include { GFASTATS as GFASTATS_PRI  } from '../../modules/nf-core/gfastats/main'
include { GFASTATS as GFASTATS_HAP  } from '../../modules/nf-core/gfastats/main'
include { BUSCO as BUSCO_PRI        } from '../../modules/nf-core/busco/main.nf'
include { BUSCO as BUSCO_HAP        } from '../../modules/nf-core/busco/main.nf'
include { MERQURYFK_MERQURYFK       } from '../../modules/nf-core/merquryfk/merquryfk/main'

include { QUAST as QUAST_PRI                     } from '../../modules/nf-core/quast/main'
include { QUAST as QUAST_HAP                     } from '../../modules/nf-core/quast/main'
include { ORTHOFINDER as ORTHOFINDER_PRI                } from '../../modules/nf-core/orthofinder/main'
include { ORTHOFINDER as ORTHOFINDER_HAP                } from '../../modules/nf-core/orthofinder/main'
include { GENOME_ONLY_BUSCO_IDEOGRAM as GENOME_ONLY_BUSCO_IDEOGRAM_PRI } from '../../modules/local/genome_only_busco_ideogram'
include { GENOME_ONLY_BUSCO_IDEOGRAM as GENOME_ONLY_BUSCO_IDEOGRAM_HAP } from '../../modules/local/genome_only_busco_ideogram'
include { BUSCO_TSV_TO_GFF as BUSCO_TSV_TO_GFF_PRI           } from '../../modules/local/busco_tsv_to_gff/main'
include { BUSCO_TSV_TO_GFF as BUSCO_TSV_TO_GFF_HAP           } from '../../modules/local/busco_tsv_to_gff/main'
include { ORTHOLOGOUS_CHROMOSOMES as ORTHOLOGOUS_CHROMOSOMES_PRI    } from '../../modules/local/orthologous_chromosomes/main'
include { ORTHOLOGOUS_CHROMOSOMES as ORTHOLOGOUS_CHROMOSOMES_HAP    } from '../../modules/local/orthologous_chromosomes/main'
include { GAWK as GAWK_PRI                       } from '../../modules/nf-core/gawk/main'
include { GAWK as GAWK_HAP                       } from '../../modules/nf-core/gawk/main'

include { TIARA_TIARA as TIARA_PRI                } from '../../modules/nf-core/tiara/tiara/main' //[ val(meta), [ fasta ] ]
include { TIARA_TIARA as TIARA_HAP                } from '../../modules/nf-core/tiara/tiara/main'

workflow GENOME_STATISTICS {
    take:
    assembly                  // channel: [ meta, primary, haplotigs ]
    lineage                   // channel: [ meta, /path/to/buscoDB, lineage ] 
    hist                      // channel: [meta, fastk_hist files]
    ktab                      // channel: [fastk_ktab files]
    fastk_pktab               // channel: [fk_pat_ktab files] it is one argument for merquryFK trio case
    phapktab                  // channel: [hapmer files]
    fastk_mktab               // channel: [fk_mat_ktab files] it is one argument for merquryFK trio case
    mhapktab                  // channel: [hapmer files]
    busco_alt                 // channel: true/false

    main:
    ch_versions = Channel.empty()
    
    // For tree plot
    ch_tree_data_pri = Channel.empty()
    ch_tree_data_hap = Channel.empty()
    //
    // LOGIC: SEPARATE PRIMARY INTO A CHANNEL
    //
    assembly.map{ meta, primary, haplotigs -> [meta, primary] }
        .set{ primary_ch }

    //
    // MODULE: RUN GFASTATS ON PRIMARY ASSEMBLY
    //
    GFASTATS_PRI( primary_ch, 'fasta', [], [], [], [], [], [] )
    ch_versions = ch_versions.mix(GFASTATS_PRI.out.versions.first())
    
    //
    // LOGIC: SEPARATE HAP INTO A CHANNEL
    //
    assembly.map{ meta, primary, haplotigs -> [meta, haplotigs] }
        .set{ haplotigs_ch }

    //
    // MODULE: RUN GFASTATS ON HAPLOTIGS
    //
    GFASTATS_HAP( haplotigs_ch, 'fasta', [], [], [], [], [], [] )

    //
    // MODULE: RUN QUAST ON PRIMARY ASSEMBLY
    //
    QUAST_PRI(
        primary_ch.map { meta, primary -> [meta, primary] },
        [[], []],
        [[], []],
    )
    ch_versions = ch_versions.mix(QUAST_PRI.out.versions.first())
    ch_tree_data_pri = ch_tree_data_pri.mix(QUAST_PRI.out.tsv.map { tuple -> tuple[1] })

    //
    // MODULE: RUN QUAST ON HAPLOTIGS
    //
    QUAST_HAP(
        haplotigs_ch.map { meta, haplotigs -> [meta, haplotigs] },
        [[], []],
        [[], []],
    )
    ch_versions = ch_versions.mix(QUAST_HAP.out.versions.first())
    ch_tree_data_hap = ch_tree_data_hap.mix(QUAST_HAP.out.tsv.map { tuple -> tuple[1] })

    // MODULE: RUN TIARA ON PRIMARY ASSEMBLY
    TIARA_PRI(
        primary_ch.map { meta, primary -> [meta, primary] }
    )
    ch_versions = ch_versions.mix(TIARA_PRI.out.versions.first())

    // MODULE: RUN TIARA ON HAPLOTIGS
    TIARA_HAP(
        haplotigs_ch.map { meta, haplotigs -> [meta, haplotigs] }
    )
    ch_versions = ch_versions.mix(TIARA_HAP.out.versions.first())

    // MODULE: RUN BUSCO ON PRIMARY ASSEMBLY
    // Assemble input tuple: [meta, fasta, mode, lineage, busco_lineages_path, config_file, clean_intermediates]

    BUSCO_PRI(
        primary_ch.map { meta, primary -> [meta, primary] },
        'genome', 
        lineage.map{ meta, lineage_db, lineage_name -> lineage_name },
        lineage.map{ meta, lineage_db, lineage_name -> lineage_db },
        [],
        false
    )
    ch_versions = ch_versions.mix(BUSCO_PRI.out.versions.first())
    
    
    //
    // MODULE: run BUSCO for haplotigs
    // USED FOR HAP1/HAP2 ASSEMBLIES
    //
    
    BUSCO_HAP(
        haplotigs_ch.map { meta, haplotigs -> [meta, haplotigs] },
        'genome',
        lineage.map{ meta, lineage_db, lineage_name -> lineage_name },
        lineage.map{ meta, lineage_db, lineage_name -> lineage_db },
        [],
        false
    )
    ch_versions = ch_versions.mix(BUSCO_HAP.out.versions.first())
    
    // GAWK_PRI(
    //     BUSCO_PRI.out.batch_summary,
    //     [],
    //     false,
    // )

    // ch_tree_data_pri = ch_tree_data_pri.mix(GAWK_PRI.out.output.collect { meta, file -> file })

    // GAWK_HAP(
    //     BUSCO_HAP.out.batch_summary,
    //     [],
    //     false,
    // )
    // ch_tree_data_hap = ch_tree_data_hap.mix(GAWK_HAP.out.output.collect { meta, file -> file })

    // ch_full_table_pri = BUSCO_PRI.out.full_table

    if (params.hifiasm_trio_on) {

        hist.join(ktab).join(assembly)
                       .set{ ch_merq }
        MERQURYFK_MERQURYFK ( ch_merq, fastk_pktab, phapktab, fastk_mktab, mhapktab )

    }
    else{
        //
        // LOGIC: JOIN ASSEMBLY AND KMER DATABASE INPUT
        //
        hist.join(ktab).join(assembly)
                        .map{ meta, hist, ktab, primary, hap -> 
                                hap.size() ? [ meta, hist, ktab, primary, hap ] :
                                    [ meta, hist, ktab, primary, [] ] } 
                        .set{ ch_merq }
        
        //
        // MODULE: RUN KMER ANALYSIS WITH MERQURYFK
        //
        MERQURYFK_MERQURYFK ( ch_merq, [], [], [], [])
    }
    ch_versions = ch_versions.mix(MERQURYFK_MERQURYFK.out.versions.first())

    emit:
    versions                  = ch_versions   
}


process GrabFiles {
    tag "${meta.id}"
    executor 'local'

    input:
    tuple val(meta), path("in")

    output:
    tuple val(meta), path("in/*.hist"), path("in/*.ktab*", hidden:true)

    "true"
}
