//
//  ViewModel.swift
//  HEREMapsExample
//
//  Created by Vladyslav Kudelia on 8/25/19.
//  Copyright © 2019 Vladyslav Kudelia. All rights reserved.
//

import NMAKit

protocol ViewModelType: class {
    var coordinates: NMAGeoCoordinates? { get }
    var appStateClosure: ((AppState)->())? { get set }
    var getPlaces: [NMAPlaceLink] { get }
    var getRouteList: [NMAPlaceLink] { get }
    var getMapObjects: [NMAMapObject] { get }
    
    func setPlaceForRoute(_ place: NMAPlaceLink)
    func removePlaces()
    func removeAllData()
    func configRoute(text: String, completion: @escaping ()->())
    func createRoute(mapView: NMAMapView)
}

final class ViewModel: NSObject, ViewModelType {

    private let coreRouter = NMACoreRouter()
    private let navigationManager = NMANavigationManager.sharedInstance()
    
    private var places: [NMAPlaceLink] = []
    private var routeList: [NMAPlaceLink] = []
    private var mapObjects: [NMAMapObject] = []
    
    private let queue = DispatchQueue(label: "SafeQueue", attributes: .concurrent)
    
    private let markerImage = UIImage(named: "marker")!
    
    var appStateClosure: ((AppState)->())?
    
    var coordinates: NMAGeoCoordinates? {
        return NMAPositioningManager.sharedInstance().currentPosition?.coordinates
    }
    
    var getPlaces: [NMAPlaceLink] {
        var result: [NMAPlaceLink] = []
        queue.sync { result = self.places }
        return result
    }
    
    var getRouteList: [NMAPlaceLink] {
        var result: [NMAPlaceLink] = []
        queue.sync { result = self.routeList }
        return result
    }
    
    var getMapObjects: [NMAMapObject] {
        var result: [NMAMapObject] = []
        queue.sync { result = self.mapObjects }
        return result
    }
    
    override init() {
        super.init()
        navigationManager.delegate = self
        navigationManager.isVoiceEnabled = false
    }
    
    func setPlaceForRoute(_ place: NMAPlaceLink) {
        queue.async(flags: .barrier) {
            self.routeList.append(place)
        }
        removePlaces()
    }
    
    func removePlaces() {
        queue.async(flags: .barrier) {
            self.places.removeAll()
        }
    }
    
    func removeAllData() {
        removePlaces()
        removeRouteList()
    }
    
    func configRoute(text: String, completion: @escaping ()->()) {
        removePlaces()
        let request = NMAPlaces.sharedInstance()?.createSearchRequest(location: coordinates, query: text)
        request?.start { [weak self] _, data, _ in
            guard let page = data as? NMADiscoveryPage else { return }
            page.discoveryResults.forEach { link in
                guard let placeLink = link as? NMAPlaceLink else { return }
                self?.setPlaceForPlaces(placeLink)
            }
            completion()
        }
    }
    
    func createRoute(mapView: NMAMapView) {
        let mode = NMARoutingMode(routingType: .fastest, transportMode: .car, routingOptions: [])
        var arrayOfCoordinates = [NMAGeoCoordinates]()
        var arrayOfMarkers = [NMAMapMarker]()
        routeList.forEach { place in
            guard let position = place.position else { return }
            arrayOfCoordinates.append(position)
            arrayOfMarkers.append(NMAMapMarker(geoCoordinates: position, image: markerImage))
        }
        coreRouter.calculateRoute(withPoints: arrayOfCoordinates, routingMode: mode) { [weak self] result, _ in
            guard let route = result?.routes?.first, let mapRoute = NMAMapRoute(route) else { return }
            mapRoute.traveledColor = .cyan
            mapRoute.color = .green
            mapRoute.outlineColor = .gray
  
            self?.resetMapObjects(arrayOfMarkers, with: mapRoute)
            self?.appStateClosure?(.route)
            self?.setupSimulation(mapView, route)
        }
    }
    
    private func resetMapObjects(_ array: [NMAMapObject], with object: NMAMapObject) {
        queue.async(flags: .barrier) {
            self.mapObjects = array
            self.mapObjects.append(object)
        }
    }
    
    private func setPlaceForPlaces(_ place: NMAPlaceLink) {
        queue.async(flags: .barrier) {
            self.places.append(place)
        }
    }
    
    private func removeRouteList() {
        queue.async(flags: .barrier) {
            self.routeList.removeAll()
        }
    }
    
    private func setupSimulation(_ mapView: NMAMapView, _ route: NMARoute) {
        navigationManager.map = mapView
        navigationManager.startTurnByTurnNavigation(route)
        navigationManager.startTracking(.car)
        
        let source = NMARoutePositionSource(route: route)
        source.movementSpeed = 85
        NMAPositioningManager.sharedInstance().dataSource = source
    }
}

extension ViewModel: NMANavigationManagerDelegate {
    func navigationManagerDidReachDestination(_ navigationManager: NMANavigationManager) {
        navigationManager.stop()
        NMAPositioningManager.sharedInstance().dataSource = nil
        removeRouteList()
        appStateClosure?(.config)
    }
}
