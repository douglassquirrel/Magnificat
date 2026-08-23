import Foundation
import libxml2

func validate(_ xml: Data, schemaPath: String) -> Bool {
    guard let pctx = xmlSchemaNewParserCtxt(schemaPath) else { return false }
    defer { xmlSchemaFreeParserCtxt(pctx) }
    guard let schema = xmlSchemaParse(pctx) else { return false }
    defer { xmlSchemaFree(schema) }
    guard let vctx = xmlSchemaNewValidCtxt(schema) else { return false }
    defer { xmlSchemaFreeValidCtxt(vctx) }
    return xml.withUnsafeBytes { buf -> Bool in
        let base = buf.bindMemory(to: CChar.self).baseAddress
        guard let doc = xmlReadMemory(base, CInt(xml.count), nil, nil,
                                      CInt(XML_PARSE_NONET.rawValue)) else { return false }
        defer { xmlFreeDoc(doc) }
        return xmlSchemaValidateDoc(vctx, doc) == 0
    }
}
let schema = CommandLine.arguments[1]
for path in CommandLine.arguments.dropFirst(2) {
    let ok = validate(try! Data(contentsOf: URL(fileURLWithPath: path)), schemaPath: schema)
    print("\(ok ? "VALID   " : "rejected") \((path as NSString).lastPathComponent)")
}
