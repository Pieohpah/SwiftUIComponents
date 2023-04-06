//
//  WebImage.swift
//  Pieus Production
//
//  Created by Peter Herber on 2023-04-06.
//

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

struct WebImage: View {
    let src:  String
    let placeholder: String
    var width: CGFloat
    var height: CGFloat
    @State private var image: UIImage?
    
    init(src: String, placeholder: String, width: CGFloat? = 0, height: CGFloat? = 0) {
        self.src = src
        self.placeholder = placeholder
        self.image = nil
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
    }
    
    func loadImage(src: String) {
        if self.image != nil {
            return
        }
        guard let url = URL(string: src) else { return }
        let request = URLRequest(url: url)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, let uii = UIImage(data: data) {
                if self.image == nil {
                    self.image = uii
                }
            } else {
                print("ERROR: WebImage:loadImage - resource not found och not displayable [\(src)]")
                print("ERROR: WebImage:loadImage - \(error?.localizedDescription ?? "")")
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

