//
//  MainView.swift
//  HEREMapsExample
//
//  Created by Vladyslav Kudelia on 8/25/19.
//  Copyright © 2019 Vladyslav Kudelia. All rights reserved.
//

import UIKit

final class MainView: UIView, NibLoadable {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var textField: UITextField!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var activityView: UIActivityIndicatorView!
    @IBOutlet private weak var startButton: UIButton!
    
    var viewModel: ViewModelType?
    var startButtonClosure: (()->())?
    
    private var state: PlacesState = .first
    
    @IBAction private func closeButtonAction(_ sender: Any) {
        reloadData()
        isHidden = true
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        textField.delegate = self
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        
        startButton.isEnabled = false
        startButton.addTarget(self, action: #selector(configRouteAction), for: .touchUpInside)
    }
    
    private func reloadData() {
        viewModel?.removeAllData()
        state = .done
        clearView()
        if activityView.isAnimating {
            activityView.stopAnimating()
        }
    }
    
    private func throttle() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(reload(_:)), object: textField)
        perform(#selector(reload(_:)), with: textField, afterDelay: 0.75)
    }
    
    private func clearView() {
        textField.text = nil
        textField.resignFirstResponder()
        
        switch state {
        case .first:
            state = .second
            titleLabel.text = Constants.secondAddress
        case .second:
            state = .third
            titleLabel.text = Constants.thirdAddress
        case .third:
            state = .done
            titleLabel.text = Constants.addressesDone
            startButton.isEnabled = true
            textField.isEnabled = false
        case .done:
            state = .first
            titleLabel.text = Constants.firstAddress
            startButton.isEnabled = false
            textField.isEnabled = true
        }
        
        tableView.reloadData()
    }
    
    @objc private func configRouteAction() {
        startButtonClosure?()
        reloadData()
        isHidden = true
    }
    
    @objc private func reload(_ textField: UITextField) {
        guard let text = textField.text else { return }
        
        viewModel?.configRoute(text: text, completion: { [weak self] in
            self?.tableView.reloadData()
            self?.activityView.stopAnimating()
        })
    }
}

extension MainView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let text = "\(textField.text ?? "")\(string)"
        if text.count > 1 {
            if !activityView.isAnimating {
                activityView.startAnimating()
            }
            throttle()
        } else {
            if activityView.isAnimating {
                activityView.stopAnimating()
            }
            viewModel?.removePlaces()
            tableView.reloadData()
        }
        
        return true
    }
}

extension MainView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        switch state {
        case .done:
            return viewModel.getRouteList.count
        default:
            return viewModel.getPlaces.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14)
        cell.selectionStyle = .none
        
        switch state {
        case .done:
            let element = viewModel?.getRouteList[indexPath.row]
            cell.textLabel?.text = "\(indexPath.row + 1)) \(element?.name ?? "")"
        default:
            let element = viewModel?.getPlaces[indexPath.row]
            cell.textLabel?.text = element?.name
        }
        
        return cell
    }
}

extension MainView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch state {
        case .done: break
        default:
            guard let element = viewModel?.getPlaces[indexPath.row] else { return }
            viewModel?.setPlaceForRoute(element)
            clearView()
        }
    }
}
