#HotIf WinActive("Lethal Company")

^k::{
	SetKeyDelay 15, 15
	Codes := "b3c1c2c7d6f2h5i1j6k9l0m6m9o5p1r2r4t2u2u9v0x8y9z3"
	CurrentCode := 1
	While(CurrentCode < StrLen(Codes)){
		Send(SubStr(Codes, CurrentCode, 2) . "{Enter}")
		Sleep 25
		CurrentCode := CurrentCode + 2
	}
}

^m::{
	Send("view monitor{Enter}")
}

^t::{
	Send("transmit ")
}

Right::{
	Send("switch{Enter}")
}

Left::{
	Send("switch{Enter}")
}

^Backspace::{
	Loop 10 {
		Send("{Backspace}")
	}
}

^f::{
	Send("store{Enter}")
}