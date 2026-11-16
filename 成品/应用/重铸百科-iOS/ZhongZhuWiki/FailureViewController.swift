//
//  FailureViewController.swift
//  重铸百科 iOS
//
//  资源缺失或端口全部被占用时的兜底页面。用纯 UIKit 画，不依赖网页资源。
//

import UIKit

final class FailureViewController: UIViewController {

    private let message: String

    init(message: String) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0xF7 / 255.0, green: 0xF8 / 255.0, blue: 0xF2 / 255.0, alpha: 1.0)

        let title = UILabel()
        title.text = "重铸百科未能启动"
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.textColor = UIColor(red: 0x25 / 255.0, green: 0x3D / 255.0, blue: 0x36 / 255.0, alpha: 1.0)
        title.textAlignment = .center

        let detail = UILabel()
        detail.text = message
        detail.font = .systemFont(ofSize: 14)
        detail.textColor = UIColor(red: 0x78 / 255.0, green: 0x85 / 255.0, blue: 0x7E / 255.0, alpha: 1.0)
        detail.numberOfLines = 0
        detail.textAlignment = .center

        let hint = UILabel()
        hint.text = "网页数据没有随 App 一起打包。请用工程里的 script/build_web_assets.py 从原始 APK 还原资源后重新构建。"
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = UIColor(red: 0x78 / 255.0, green: 0x85 / 255.0, blue: 0x7E / 255.0, alpha: 1.0)
        hint.numberOfLines = 0
        hint.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [title, detail, hint])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
}
