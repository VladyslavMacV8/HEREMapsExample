//
//  ViewController.swift
//  HEREMapsExample
//
//  Created by Vladyslav Kudelia on 8/25/19.
//  Copyright © 2019 Vladyslav Kudelia. All rights reserved.
//

import UIKit
import NMAKit

final class ViewController: UIViewController {
    
    @IBOutlet private weak var mapView: NMAMapView!
    @IBOutlet private weak var setButton: UIButton!
    
    private var viewModel: ViewModelType!
    private let mainView = MainView.loadFromNib()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel = ViewModel(mapView: mapView)
        setupViews()
        setupSignals()
        setupObserver()
    }
    
    private func setupViews() {
        mapView.positionIndicator.isVisible = true
        setButton.addTarget(self, action: #selector(setButtonAction), for: .touchUpInside)
    }
    
    private func setupSignals() {
        viewModel.appStateClosure = { [weak self] in
            guard let strongSelf = self else { return }
            if strongSelf.viewModel.appState == .route {
                strongSelf.setButton.isHidden = true
                strongSelf.mapView.add(mapObjects: strongSelf.viewModel.getMapObjects)
            } else {
                strongSelf.setButton.isHidden = false
                strongSelf.mapView.remove(mapObjects: strongSelf.viewModel.getMapObjects)
                NotificationCenter.default.removeObserver(strongSelf)
            }
            strongSelf.setupObserver()
        }
    }
    
    private func setupObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(didUpdatePosition), name: .NMAPositioningManagerDidUpdatePosition, object: nil)
    }
    
    @objc private func didUpdatePosition() {
        guard let coordinates = NMAPositioningManager.sharedInstance().currentPosition?.coordinates else { return }
        if viewModel.appState == .config {
            mapView.set(geoCenter: coordinates, zoomLevel: 13.25, animation: .none)
            NotificationCenter.default.removeObserver(self)
        } else {
            viewModel.trackMarkers(currentCoordinate: coordinates)
        }
    }
    
    @objc private func setButtonAction() {
        for sub in view.subviews where sub.isKind(of: MainView.self) {
            sub.isHidden = false
            return
        }
        
        mainView.viewModel = viewModel
        mainView.startButtonClosure = { [weak self] in
            self?.viewModel.createRoute()
        }
        mainView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainView)
        
        let topAnchor = mainView.topAnchor.constraint(equalTo: view.topAnchor, constant: 25)
        let centerXAnchor = mainView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        let heightAnchor = mainView.heightAnchor.constraint(equalToConstant: view.frame.height * 0.55)
        let widthAnchor = mainView.widthAnchor.constraint(equalToConstant: view.frame.width * 0.9)
        NSLayoutConstraint.activate([centerXAnchor, topAnchor, heightAnchor, widthAnchor])
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

