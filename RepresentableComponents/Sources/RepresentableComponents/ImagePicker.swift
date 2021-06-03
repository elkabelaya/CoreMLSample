//
//  ImagePicker.swift
//
//
//  Created by Elka Belaya on 02.06.2021.
//
import SwiftUI
public struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding public var image: UIImage?

        
    
    public init(image: Binding<UIImage?>){
        _image = image
    }
    
    public func makeCoordinator() -> ImageCoordinator {
        //Coordinator()
        ImageCoordinator(self)
    }
    public func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {

    }
}

public class ImageCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    var parent: ImagePicker

    init(_ parent: ImagePicker) {
        self.parent = parent
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let uiImage = info[.originalImage] as? UIImage {
            parent.image = uiImage
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
    
}



