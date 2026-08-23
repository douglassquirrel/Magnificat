import Foundation

var output = StandardOutput()
let code = MagnificatCLI.run(arguments: Array(CommandLine.arguments.dropFirst()),
                             output: &output)
exit(code)
