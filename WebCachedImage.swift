//
//  WebCachedImage.swift
//
//  Created by Peter Herber on 2023-04-06.
//
//  Dependency: Persistence.swift

//    The MIT License (MIT)
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.

import UIKit
import SwiftUI

struct WebCacheMeta: Codable {
    var urlString: String
    var fileName: String
    var created: Date
}

typealias WebCache = [WebCacheMeta]

struct WebCachedImage: View {
    static let cacheFolderName = "WebCachedImages"
    static let metaBundleName = "WebCachedMeta"
    let src:  String
    let placeholder: String
    var width: CGFloat
    var height: CGFloat
    var expiryDaysInterval: Double
    lazy var meta: WebCache = metaCache()
    private let compression = 0.7
    @State private var image: UIImage?
    
    init(src: String, placeholder: String, width: CGFloat? = 0, height: CGFloat? = 0, expiryDays: Int = 1) {
        self.src = src
        self.placeholder = placeholder
        self.image = nil
        self.expiryDaysInterval = Double(expiryDays)
        if width == 0 || height == 0 {
            if let s = UIImage(named: placeholder)?.size {
                self.width = s.width
                self.height = s.height
            }
            else {
                self.width = 40.0
                self.height = 40.0
            }
        } else {
            self.width = width!
            self.height = height!
        }
        meta = metaCache()
    }
    
    func loadImage(src: String) {
        if self.image != nil {
            return
        }
        if let img = cachedImage(src) {
            self.image = img
            return
        }
        
        guard let url = URL(string: src) else { return }
        let request = URLRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, let uii = UIImage(data: data) {
                if self.image == nil {
                    if !saveImage(src, image: uii) {
                        print("Could not save image")
                    }
                    self.image = uii
                }
            } else {
                print("Error - WebCachedImage.loadImage - resource not found och not displayable [\(src)]")
                print("Error - WebCachedImage.loadImage - \(error?.localizedDescription ?? "")")
            }
        }.resume()
    }
    
    var body: some View {
        Image(uiImage: self.image == nil ? UIImage(named: placeholder)! : self.image!)
            .resizable()
            .frame(width: self.width, height: self.height)
            .onAppear {
                loadImage(src: src)
            }
    }
}

extension WebCachedImage {
    private func metaCache() -> WebCache {
        if let dict = Persistence.loadBundle(name: WebCachedImage.metaBundleName, WebCache.self) {
            return dict
        }
        return WebCache()
    }
    private func saveMetaCache(_ meta: WebCache) -> Bool {
        if let ok = try? Persistence.saveBundle(name: WebCachedImage.metaBundleName, data: meta) {
            return ok
        }
        return false
    }
    
    private func cacheFolder() -> URL? {
        if let bundleFolder = Persistence.bundleRootDirectory {
            let folder = bundleFolder.appendingPathComponent(WebCachedImage.cacheFolderName)
            return folder
        }
        return nil
    }
    
    private func cachedImage(_ urlStr: String) -> UIImage? {
        
        let m = metaCache().filter({ wm in
            wm.urlString == urlStr
        })
        
        if let meta = m.first {
            if let image = try? fileContent(fileName: meta.fileName) {
                if isExpired(meta) {
                    updateExpiredCache()
                    return nil
                }
                return image
            } else {
                let mc = metaCache().filter({ wm in
                    wm.urlString != urlStr
                })
                let s = saveMetaCache(mc)
                print("Error - WebCachedImage.cachedImage: Not valid image. Removed meta for \(urlStr), save meta: \(s.description)")
            }
        }
        return nil
    }
    
    private func isExpired(_ meta: WebCacheMeta) -> Bool {
        let secInDay = 60 * 60 * 24
        //print("WEBCACHEDIMAGE: Image age: \(Date.now.timeIntervalSince(meta.created)) - expiry \(expiryDaysInterval * Double(secInDay))")
        if Date.now.timeIntervalSince(meta.created) > (expiryDaysInterval * Double(secInDay)) {
            return true
        }
        return false
    }
    
    private func updateExpiredCache() {
        print("WEBCACHEDIMAGE: Clear expired images")
        let currentMeta = metaCache()
        
        let validMeta = currentMeta.filter({ wm in
            return !isExpired(wm)
        })
        let s = saveMetaCache(validMeta)
        
        let expiredMeta = currentMeta.filter({ wm in
            return isExpired(wm)
        })
        for em in expiredMeta {
            do{
                try removeImage(em)
            } catch {
                print("WEBCACHEDIMAGE: Could not delete \(em.fileName)")
            }
        }
    }
    
    private func removeImage(_ meta: WebCacheMeta) throws {
        let fileName = meta.fileName
        let _url = cacheFolder()
        guard let url = _url else {
            throw PersistentError.DirectoryError
        }
        let fileUrl = url.appendingPathComponent(fileName)
        try BundleFileManager.shared.deleteFile(url: fileUrl)
    }
    
    private func saveImage(_ urlString: String, image: UIImage) -> Bool {
        let date = Date.now
        let fileName = "\(date.timeIntervalSince1970)"
        do {
            if try writeFile(filename: fileName, content: image) {
                let meta = WebCacheMeta(urlString: urlString, fileName: fileName, created: date)
                var cache = metaCache()
                cache.append(meta)
                let ok = saveMetaCache(cache)
                return ok
            } else {
                print("Error - WebCachedImage.saveImage: Could not save image")
            }
        } catch {
            print("Error - WebCachedImage.saveImage: \(error.localizedDescription)")
        }

        return false
    }
    
    private func fileContent(fileName: String, url: URL? = nil) throws -> UIImage? {
        do {
            let _url = url ?? cacheFolder()
            guard let url = _url else {
                throw PersistentError.DirectoryError
            }
            
            let fileURL = url.appendingPathComponent(fileName)
            if let content = try? Data(contentsOf: fileURL) {
                if let image = UIImage(data: content) {
                    return image
                }
            }
        } catch {
            throw PersistentError.FileNotFound
        }
        return nil
    }
    
    private func writeFile(filename: String, content: UIImage, url: URL? = nil) throws -> Bool {
        do {
            let _url = url ?? cacheFolder()
            guard let url = _url else {
                throw PersistentError.DirectoryError
            }
            if let data =  content.jpegData(compressionQuality: compression) {
                if try BundleFileManager.shared.writeFile(filename: filename, content: data, url: url) {
                    return true
                }
            }
        } catch {
            print(error.localizedDescription)
            throw PersistentError.CreateError
        }
        return false
    }
}
