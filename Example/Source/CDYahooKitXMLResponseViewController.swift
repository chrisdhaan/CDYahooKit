//
//  CDYahooKitXMLResponseViewController.swift
//  iOS Example
//

import UIKit

/// Displays a re-indented XML response body, pushed onto the navigation stack so the user can
/// tap back to return to the endpoint list.
final class CDYahooKitXMLResponseViewController: UIViewController {

    private let xmlText: String

    init(title: String, xmlText: String) {
        self.xmlText = xmlText
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.text = xmlText
        textView.backgroundColor = .systemBackground
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.alwaysBounceVertical = true
        view = textView
    }
}
