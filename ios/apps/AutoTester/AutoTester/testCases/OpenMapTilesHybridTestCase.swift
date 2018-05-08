//
//  OpenMapTilesTestCase.swift
//  AutoTester
//
//  Created by Stephen Gifford on 12/23/17.
//  Copyright © 2017 Saildrone. All rights reserved.
//

import Foundation

class OpenMapTilesHybridTestCase: MaplyTestCase {
    
    override init() {
        super.init()
        
        self.name = "OpenMapTiles Hybrid Test Case"
        self.captureDelay = 4
        self.implementations = [.map, .globe]
    }
    
    // Set up an OpenMapTiles display layer
    func setupLayer(_ baseVC: MaplyBaseViewController) -> MaplyQuadSamplingLayer?
    {
        guard let path = Bundle.main.path(forResource: "SE_Basic", ofType: "json") else {
            return nil
        }
        guard let styleData = NSData.init(contentsOfFile: path) else {
            return nil
        }
        
        // Set up an offline renderer and a Mapbox vector style handler to render to it
        let imageSize = (width: 512.0, height: 512.0)
        guard let offlineRender = MaplyRenderController.init(size: CGSize.init(width: imageSize.width, height: imageSize.height)) else {
            return nil
        }
        let imageStyleSettings = MaplyVectorStyleSettings.init(scale: UIScreen.main.scale)
        imageStyleSettings.arealShaderName = kMaplyShaderDefaultTriNoLighting
        guard let imageStyleSet = MapboxVectorStyleSet.init(json: styleData as Data,
                                                            settings: imageStyleSettings,
                                                            viewC: offlineRender,
                                                            filter:
            { (styleAttrs) -> Bool in
                // We only want polygons for the image
                if let type = styleAttrs["type"] as? String {
                    if type == "background" || type == "fill" {
                        return true
                    }
                }
                return false
        })
            else {
                return nil
        }
        
        // Set up a style for just the vector data we want to overlay
        let vectorSettings = MaplyVectorStyleSettings.init(scale: UIScreen.main.scale)
        vectorSettings.baseDrawPriority = 100+1
        vectorSettings.drawPriorityPerLevel = 1000
        guard let vectorStyleSet = MapboxVectorStyleSet.init(json: styleData as Data,
                                                             settings: vectorSettings,
                                                             viewC: baseVC,
                                                             filter:
            { (styleAttrs) -> Bool in
                // We want everything but the polygons
                if let type = styleAttrs["type"] as? String {
                    if type != "background" && type != "fill" {
                        return true
                    }
                }
                return false
        })
            else {
                return nil
        }
        
        // Set up the tile info (where the data is) and the tile source to interpet it
        let tileInfo = MaplyRemoteTileInfo.init(baseURL: "http://public-mobile-data-stage-saildrone-com.s3-us-west-1.amazonaws.com/openmaptiles/{z}/{x}/{y}.png", ext: nil, minZoom: 0, maxZoom: 14)
        let cacheDir = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        let tileSource = MapboxVectorTileImageSource(tileInfo: tileInfo, imageStyle: imageStyleSet, offlineRender: offlineRender, vectorStyle: vectorStyleSet, viewC: baseVC)
        if let tileSource = tileSource {
            tileSource.cacheDir = "\(cacheDir)/openmaptiles_saildrone/"
            
            guard let imageLoader = MaplyQuadImageLoader(tileSource: tileSource, viewC: baseVC) else {
                return nil
            }
            imageLoader.numSimultaneousFetches = 8
            let coordSys = MaplySphericalMercator(webStandard: ())
            guard let sampleLayer = MaplyQuadSamplingLayer.init(coordSystem: coordSys, imageLoader: imageLoader) else {
                return nil
            }
            sampleLayer.baseDrawPriority = vectorSettings.baseDrawPriority-1
            sampleLayer.drawPriorityPerLevel = vectorSettings.drawPriorityPerLevel
            // Note: Get this from the tiles source
            sampleLayer.setMinZoom(tileInfo.minZoom, maxZoom: tileInfo.maxZoom, importance: 1024.0*1024.0)
            if baseVC is WhirlyGlobeViewController {
                sampleLayer.edgeMatching = true
                sampleLayer.coverPoles = true
            }
            
            return sampleLayer
        }
        
        return nil
    }
    
    override func setUpWithMap(_ mapVC: MaplyViewController) {
        //        mapVC.performanceOutput = true
        
        if let layer = setupLayer(mapVC) {
            mapVC.add(layer)
        }
    }
    
    override func setUpWithGlobe(_ globeVC: WhirlyGlobeViewController) {
        //        globeVC.performanceOutput = true
        
        if let layer = setupLayer(globeVC) {
            globeVC.add(layer)
        }
    }
}

