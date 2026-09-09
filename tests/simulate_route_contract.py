"""Small pure-Python mirror for the routing contract.
This is not the game; it catches broken level data before Godot runtime tests.
"""
from dataclasses import dataclass

@dataclass
class Junction:
    a: str
    b: str
    state: int = 0
    queued: bool = False
    animating: bool = False

    @property
    def output(self):
        return self.a if self.state == 0 else self.b

    def request_toggle(self):
        if self.animating:
            self.queued = True
            return
        self.state = 1 - self.state
        self.animating = True

    def finish_animation(self):
        self.animating = False
        if self.queued:
            self.queued = False
            self.request_toggle()


def self_test():
    j = Junction('LEFT','RIGHT')
    assert j.output == 'LEFT'
    j.request_toggle()
    committed = j.output
    assert committed == 'RIGHT'
    j.request_toggle()  # queued, not immediately applied
    assert j.output == 'RIGHT'
    assert committed == 'RIGHT'  # existing item route stays committed
    j.finish_animation()
    assert j.output == 'LEFT'
    print('routing contract mirror: PASS')

if __name__ == '__main__':
    self_test()
