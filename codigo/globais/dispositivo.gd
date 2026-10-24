extends RefCounted
## Aparelho de toque de verdade: Android/iOS nativos ou o jogo aberto no navegador de um celular/tablet (iPhone, iPad, Android).
## No navegador, quem decide é o dedo como ponteiro principal (pointer: coarse); notebook com tela de toque e mouse não conta.
## Sem referências a autoloads: pode ser carregado por qualquer script, mesmo no início da inicialização.
static func celular() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android"):
		return true
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("window.matchMedia('(pointer: coarse) and (hover: none)').matches", true) == true
	return false
