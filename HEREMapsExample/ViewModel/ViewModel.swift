//
//  ViewModel.swift
//  HEREMapsExample
//
//  Created by Vladyslav Kudelia on 8/25/19.
//  Copyright © 2019 Vladyslav Kudelia. All rights reserved.
//

import NMAKit
import AVFoundation

protocol ViewModelType: class {
    var appState: AppState { get }
    var appStateClosure: (()->())? { get set }
    var getPlaces: [NMAPlaceLink] { get }
    var getRouteList: [NMAPlaceLink] { get }
    var getMapObjects: [NMAMapObject] { get }
    
    func setPlaceForRoute(_ place: NMAPlaceLink)
    func removePlaces()
    func removeAllData()
    func configRoute(text: String, completion: @escaping ()->())
    func createRoute()
    func trackMarkers(currentCoordinate: NMAGeoCoordinates)
}

final class ViewModel: NSObject, ViewModelType {

    private let coreRouter = NMACoreRouter()
    private let navigationManager = NMANavigationManager.sharedInstance()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    private var places: [NMAPlaceLink] = []
    private var routeList: [NMAPlaceLink] = []
    private var mapObjects: [NMAMapObject] = []
    private var waypoints: [WaypointEntity] = []
    
    private let queue = DispatchQueue(label: "ConcurrentQueue", attributes: .concurrent)
    
    private let markerImage = UIImage(named: "marker")!

    var appState: AppState = .config
    var appStateClosure: (()->())?
    
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
    
    init(mapView: NMAMapView) {
        super.init()
        navigationManager.map = mapView
        navigationManager.delegate = self
        navigationManager.isVoiceEnabled = false
        speechSynthesizer.delegate = self
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
        let request = NMAPlaces.sharedInstance()?.createSearchRequest(location: NMAPositioningManager.sharedInstance().currentPosition?.coordinates, query: text)
        request?.start { [weak self] _, data, _ in
            guard let page = data as? NMADiscoveryPage else { return }
            page.discoveryResults.forEach { link in
                guard let placeLink = link as? NMAPlaceLink else { return }
                self?.setPlaceForPlaces(placeLink)
            }
            completion()
        }
    }
    
    func createRoute() {
        let mode = NMARoutingMode(routingType: .fastest, transportMode: .car, routingOptions: [])
        var arrayOfCoordinates = [NMAGeoCoordinates]()
        var arrayOfMarkers = [NMAMapMarker]()
        for (index, place) in routeList.enumerated() {
            guard let position = place.position else { return }
            waypoints.append(WaypointEntity(name: "point \(index + 1)", position: position, isCheck: false))
            arrayOfCoordinates.append(position)
            arrayOfMarkers.append(NMAMapMarker(geoCoordinates: position, image: markerImage))
        }
        coreRouter.calculateRoute(withPoints: arrayOfCoordinates, routingMode: mode) { [weak self] result, _ in
            guard let route = result?.routes?.first, let mapRoute = NMAMapRoute(route) else { return }
            mapRoute.traveledColor = .cyan
            mapRoute.color = .green
            mapRoute.outlineColor = .gray
            
            self?.resetMapObjects(arrayOfMarkers, with: mapRoute)
            self?.appState = .route
            self?.appStateClosure?()
            self?.setupSimulation(route)
        }
    }
    
    func trackMarkers(currentCoordinate: NMAGeoCoordinates) {
        waypoints.forEach { waypoint in
            if waypoint.position.distance(to: currentCoordinate) < 30 && !waypoint.isCheck {
                waypoint.isCheck = true
                queue.async { self.speechPoint(waypoint.name) }
            }
        }
    }
    
    private func resetMapObjects(_ array: [NMAMapMarker], with object: NMAMapRoute) {
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
            self.waypoints.removeAll()
        }
    }
    
    private func setupSimulation(_ route: NMARoute) {
        navigationManager.startTurnByTurnNavigation(route)
        navigationManager.startTracking(.car)
        
        let source = NMARoutePositionSource(route: route)
        source.movementSpeed = 45
        NMAPositioningManager.sharedInstance().dataSource = source
    }
    
    private func speechPoint(_ value: String) {
        prepareAVSession()
        let speechUtterance = AVSpeechUtterance(string: "You drived \(value)")
        speechSynthesizer.speak(speechUtterance)
    }
    
    private func prepareAVSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: .defaultToSpeaker)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        }
        catch  {
            print(error.localizedDescription)
        }
    }
    
    private func disableAVSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print(error.localizedDescription)
        }
    }
}

extension ViewModel: NMANavigationManagerDelegate {
    func navigationManagerDidReachDestination(_ navigationManager: NMANavigationManager) {
        NMAPositioningManager.sharedInstance().dataSource = nil
        removeRouteList()
        appState = .config
        appStateClosure?()
    }
}

extension ViewModel: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        disableAVSession()
    }
}
