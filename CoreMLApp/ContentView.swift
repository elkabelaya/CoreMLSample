//
//  ContentView.swift
//  CoreMLApp
//
//  Created by Elka Belaya on 02.06.2021.
//

import SwiftUI
import RepresentableComponents
struct ContentView: View {
    @State var image: UIImage?
    var body: some View {
        NavigationView {
            VStack {
                
                NavigationLink(destination: ImagePicker(image: $image)){
                    Text("Select Image")
                }
                if let uiImage = image,
                    let swiftUIImage = Image(uiImage: uiImage){
                        swiftUIImage
                        .resizable()
                        .scaledToFit()
                }
                
                /*VisionDetectionView()
                    .environmentObject(object:)*/
            }
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(image: nil)
    }
}
