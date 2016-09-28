import Foundation

extension FileManager {
    func absolutePath(for filePath: String) -> String? {
        let url = URL(fileURLWithPath: filePath)
        do {
            guard try url.checkResourceIsReachable() else { return nil }
        } catch { return nil }
        
        let absoluteURL = url.absoluteString
        
        return absoluteURL.components(separatedBy: "file://").last
    }
}
