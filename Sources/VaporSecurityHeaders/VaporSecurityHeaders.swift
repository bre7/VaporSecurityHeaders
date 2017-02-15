import HTTP

struct SecurityHeaders: Middleware {
    
    private let enableHSTS: Bool
    private let specifications: [SecurityHeaderSpecification]
    
    init(api: Bool, enableHSTS: Bool = false) {
        if api {
            self.init(contentTypeSpecification: ContentTypeOptionsSpec(option: .nosniff),
                      contentSecurityPolicySpecification: ContentSecurityPolicySpec(value: "default-src 'none'"),
                      enableHSTS: enableHSTS)
        }
        else {
            self.init(enableHSTS: enableHSTS)
        }
    }
    
    init(contentTypeSpecification: ContentTypeOptionsSpec = ContentTypeOptionsSpec(option: .nosniff),
         contentSecurityPolicySpecification: ContentSecurityPolicySpec = ContentSecurityPolicySpec(value: "default-src 'self'"),
         enableHSTS: Bool = false) {
        specifications = [contentTypeSpecification, contentSecurityPolicySpecification]
        self.enableHSTS = enableHSTS
    }
    
    enum HeaderNames {
        case cto
        case csp
        case xfo
        case xssProtection
        case hsts
    }
    
    
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        let response = try next.respond(to: request)

        response.headers[HeaderKey.contentSecurityPolicy] = getHeader(for: .csp)
        response.headers[HeaderKey.xFrameOptions] = getHeader(for: .xfo)
        response.headers[HeaderKey.xXssProtection] = getHeader(for: .xssProtection)
        
        if enableHSTS {
            response.headers[HeaderKey.strictTransportSecurity] = getHeader(for: .hsts)
        }
        
        for spec in specifications {
            spec.setHeader(on: response)
        }
        
        return response
    }
    
    private func getHeader(for headerName: HeaderNames) -> String {
        switch headerName {
        case .xfo:
            return "deny"
        case .xssProtection:
            return "1; mode=block"
        case .hsts:
            return "max-age=31536000; includeSubdomains; preload"
        default:
            return ""
        }
    }
}

struct ContentSecurityPolicySpec: SecurityHeaderSpecification {
    
    private let value: String
    
    init(value: String) {
        self.value = value
    }

    func setHeader(on response: Response) {
        response.headers[HeaderKey.contentSecurityPolicy] = value
    }
}


struct ContentTypeOptionsSpec: SecurityHeaderSpecification {
    
    private let option: Options
    
    init(option: Options) {
        self.option = option
    }
    
    enum Options {
        case nosniff
        case none
    }
    
    func setHeader(on response: Response) {
        switch option {
        case .nosniff:
            response.headers[HeaderKey.xContentTypeOptions] = "nosniff"
        default:
            break
        }
    }
}

protocol SecurityHeaderSpecification {
    func setHeader(on response: Response)
}

extension HeaderKey {
    static public var contentSecurityPolicy: HeaderKey {
        return HeaderKey("Content-Security-Policy")
    }
    
    static public var xXssProtection: HeaderKey {
        return HeaderKey("X-XSS-Protection")
    }
    
    static public var xFrameOptions: HeaderKey {
        return HeaderKey("X-Frame-Options")
    }
    
    static public var xContentTypeOptions: HeaderKey {
        return HeaderKey("X-Content-Type-Options")
    }
}
