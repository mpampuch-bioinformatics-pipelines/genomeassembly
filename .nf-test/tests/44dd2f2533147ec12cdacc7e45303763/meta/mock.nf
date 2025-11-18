import groovy.json.JsonGenerator
import groovy.json.JsonGenerator.Converter

nextflow.enable.dsl=2

// comes from nf-test to store json files
params.nf_test_output  = ""

// include dependencies


// include test process
include { SMUDGEPLOT_HETMERS } from '/ibex/project/c2303/20251019_Galdi-T2T-Assembly/SANGERTOL-TEST/GENOME-ASSEMBLER-TEST_Local_fork_rev_0c2aae85173eba12446e3f325431653e2d697c22/genomeassembly/modules/local/smudgeplot/hetmers/tests/../main.nf'

// define custom rules for JSON that will be generated.
def jsonOutput =
    new JsonGenerator.Options()
        .addConverter(Path) { value -> value.toAbsolutePath().toString() } // Custom converter for Path. Only filename
        .build()

def jsonWorkflowOutput = new JsonGenerator.Options().excludeNulls().build()


workflow {

    // run dependencies
    

    // process mapping
    def input = []
    
                input[0] = [
                    [ id: 'Galderia_gt20kb_50x' ],
                    file('/ibex/scratch/projects/c2303/20251019_Galdi-T2T-Assembly/TESTS/TEST_DATA/KMERS/*.ktab*')
                ]
                
    //----

    //run process
    SMUDGEPLOT_HETMERS(*input)

    if (SMUDGEPLOT_HETMERS.output){

        // consumes all named output channels and stores items in a json file
        for (def name in SMUDGEPLOT_HETMERS.out.getNames()) {
            serializeChannel(name, SMUDGEPLOT_HETMERS.out.getProperty(name), jsonOutput)
        }	  
      
        // consumes all unnamed output channels and stores items in a json file
        def array = SMUDGEPLOT_HETMERS.out as Object[]
        for (def i = 0; i < array.length ; i++) {
            serializeChannel(i, array[i], jsonOutput)
        }    	

    }
  
}

def serializeChannel(name, channel, jsonOutput) {
    def _name = name
    def list = [ ]
    channel.subscribe(
        onNext: {
            list.add(it)
        },
        onComplete: {
              def map = new HashMap()
              map[_name] = list
              def filename = "${params.nf_test_output}/output_${_name}.json"
              new File(filename).text = jsonOutput.toJson(map)		  		
        } 
    )
}


workflow.onComplete {

    def result = [
        success: workflow.success,
        exitStatus: workflow.exitStatus,
        errorMessage: workflow.errorMessage,
        errorReport: workflow.errorReport
    ]
    new File("${params.nf_test_output}/workflow.json").text = jsonWorkflowOutput.toJson(result)
    
}
