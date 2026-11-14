//
//  RendererType.swift
//  Azeroth Launcher
//
//  Created by Матвей on 07.11.2026.
//

import Foundation

enum RendererType: String, Codable, CaseIterable, Identifiable{
    case dxvk
    case metal
    
    var id: String{
        rawValue
    }
    
    var title: String{
        switch self{
            case .dxvk: return "DXVK"
            case .metal: return "Metal (MTLd3D)"
        }
    }
    
    var description: String{
        switch self{
            case .dxvk: return "Direct3D via Vulkan"
            case .metal: return "Direct3D via Apple Metal"
        }
    }
}
