import Foundation

/// Área de transferência do sistema; a implementação fica em `CaptaSistema`.
public protocol AreaDeTransferencia: Sendable {
    func copiarPNG(_ dados: Data) throws
}

/// Painel de salvar do sistema; `nil` significa que o usuário cancelou.
@MainActor
public protocol PainelDeArquivos {
    func escolherDestino(nomeSugerido: String, extensao: String) async -> URL?
}

/// Permissão de gravação de tela.
public protocol PermissaoDeGravacaoDeTela: Sendable {
    func consultar() -> Bool
    func solicitar()
}

/// Teclas modificadoras de um atalho.
public struct Modificadores: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let controle = Modificadores(rawValue: 1 << 0)
    public static let opcao = Modificadores(rawValue: 1 << 1)
    public static let comando = Modificadores(rawValue: 1 << 2)
    public static let shift = Modificadores(rawValue: 1 << 3)
}

/// Atalho global: código de tecla virtual (só um número, o núcleo não importa Carbon) e modificadores.
public struct CombinacaoDeTeclas: Equatable, Sendable {
    public let codigoDaTecla: UInt32
    public let modificadores: Modificadores

    public init(codigoDaTecla: UInt32, modificadores: Modificadores) {
        self.codigoDaTecla = codigoDaTecla
        self.modificadores = modificadores
    }

    /// ⌃⌥F (código `3`, o `kVK_ANSI_F`).
    public static let capturarTelaInteira = CombinacaoDeTeclas(
        codigoDaTecla: 3,
        modificadores: [.controle, .opcao]
    )
}

public enum ErroAtalho: Error, Equatable, Sendable {
    /// A combinação já está em uso.
    case conflito
    case falhou
}

/// Registro de atalho global do sistema.
public protocol AtalhoGlobal: Sendable {
    func registrar(
        _ combinacao: CombinacaoDeTeclas,
        acao: @escaping @Sendable () -> Void
    ) throws
}
