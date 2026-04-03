import { useState, useEffect, useCallback } from "react"
import { motion, AnimatePresence } from "motion/react"
// logo import removed — using emoji buddy instead

/**
 * High-fidelity MacBook mockup showing CodeIsland's actual UI states:
 * 1. Collapsed notch (left/right wing layout)
 * 2. Expanded session list with status badges
 * 3. Chat view with diff preview
 * 4. Approval panel
 */

type DemoState = "collapsed" | "sessions" | "chat" | "approval"

const states: DemoState[] = ["collapsed", "sessions", "chat", "approval"]
const stateLabels: Record<DemoState, string> = {
  collapsed: "折叠态监控",
  sessions: "会话列表",
  chat: "对话详情",
  approval: "权限审批",
}

export default function MacBookMockup() {
  const [current, setCurrent] = useState<DemoState>("collapsed")
  const [auto, setAuto] = useState(true)

  const next = useCallback(() => {
    setCurrent(s => {
      const i = states.indexOf(s)
      return states[(i + 1) % states.length]
    })
  }, [])

  useEffect(() => {
    if (!auto) return
    const t = setInterval(next, 4000)
    return () => clearInterval(t)
  }, [auto, next])

  const select = (s: DemoState) => {
    setCurrent(s)
    setAuto(false)
    setTimeout(() => setAuto(true), 12000)
  }

  return (
    <div className="relative w-full max-w-[900px] mx-auto" style={{ animation: 'heroEnter 1.2s ease-out 0.3s both' }}>
      {/* Screen glow */}
      <div className="absolute -inset-8 bg-[radial-gradient(ellipse_at_center,rgba(124,58,237,0.12)_0%,transparent_70%)] blur-2xl pointer-events-none" />

      {/* State selector pills */}
      <div className="flex justify-center gap-2 mb-4">
        {states.map(s => (
          <button
            key={s}
            onClick={() => select(s)}
            className={`font-mono text-[11px] px-3 py-1.5 rounded-full transition-all duration-300 ${
              current === s
                ? "bg-green/20 text-green border border-green/30"
                : "text-white/40 hover:text-white/60 border border-transparent"
            }`}
          >
            {stateLabels[s]}
          </button>
        ))}
      </div>

      {/* MacBook Screen */}
      <div className="relative rounded-xl overflow-hidden border border-white/[0.08] shadow-[0_20px_80px_rgba(0,0,0,0.6)]">
        <div
          className="relative w-full aspect-[16/10]"
          style={{ background: 'linear-gradient(135deg, #1a0533 0%, #0c1445 25%, #1e3a5f 50%, #3a1d5c 75%, #1a0533 100%)' }}
        >
          {/* Wallpaper orbs */}
          <div className="absolute top-1/4 left-1/3 w-64 h-64 rounded-full bg-purple-600/20 blur-[80px]" />
          <div className="absolute bottom-1/4 right-1/4 w-48 h-48 rounded-full bg-blue-500/15 blur-[60px]" />
          <div className="absolute top-1/2 right-1/3 w-56 h-56 rounded-full bg-pink-500/10 blur-[70px]" />

          {/* Menu bar */}
          <div className="relative flex items-center justify-between px-4 h-7" style={{ background: 'rgba(0,0,0,0.25)', backdropFilter: 'blur(20px)' }}>
            <div className="flex items-center gap-4 font-mono text-[10px] text-white/80">
              <span className="font-bold"></span>
              <span>CodeIsland</span>
              <span className="text-white/50">File</span>
              <span className="text-white/50">Edit</span>
            </div>

            {/* Notch — always centered */}
            <div className="absolute left-1/2 -translate-x-1/2 top-0 z-20">
              <AnimatePresence mode="wait">
                {current === "collapsed" ? (
                  <CollapsedNotch key="collapsed" />
                ) : (
                  <ExpandedPanel key={current} state={current} />
                )}
              </AnimatePresence>
            </div>

            <div className="flex items-center gap-3 font-mono text-[10px] text-white/50">
              <span>Wi-Fi</span>
              <span>{new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
            </div>
          </div>

          {/* Terminal windows on desktop */}
          <div className="relative px-5 pt-16 pb-4 flex gap-3 z-10">
            <TerminalWindow title="claude — CodeIsland" className="flex-1 max-w-[55%]">
              <div><span className="text-green">●</span> <span className="text-white/70">让我看看 NotchView 的布局代码。</span></div>
              <div className="mt-1.5"><span className="text-purple-400">●</span> <span className="text-white/50">Read NotchView.swift</span></div>
              <div className="mt-1.5"><span className="text-purple-400">●</span> <span className="text-white/50">Edit ClaudeInstancesView.swift</span></div>
              <div className="mt-3 rounded border border-white/[0.06] overflow-hidden">
                <div className="bg-green/10 text-green/80 px-2 py-0.5 text-[10px]">+ Text("进行中").foregroundColor(.cyan)</div>
                <div className="bg-red-500/10 text-red-400/80 px-2 py-0.5 text-[10px]">- Text("Working...")</div>
              </div>
              <div className="mt-2"><span className="text-green">●</span> <span className="text-white/70">编译通过，重启中...</span></div>
              <div className="mt-1 text-white/20"><span className="animate-pulse">▊</span></div>
            </TerminalWindow>

            <TerminalWindow title="claude — icare" className="flex-1 max-w-[45%]">
              <div><span className="text-amber-400">●</span> <span className="text-white/70">分析项目结构中。</span></div>
              <div className="mt-1.5"><span className="text-purple-400">●</span> <span className="text-white/50">Bash: npm install</span></div>
              <div className="mt-1.5 text-white/40 text-[10px]">安装依赖中...</div>
              <div className="mt-1.5"><span className="text-purple-400">●</span> <span className="text-white/50">Write: src/App.tsx</span></div>
              <div className="mt-2 text-white/20"><span className="animate-pulse">▊</span></div>
            </TerminalWindow>
          </div>
        </div>
      </div>
    </div>
  )
}

// ─── Collapsed Notch ───

function CollapsedNotch() {
  return (
    <motion.div
      initial={{ width: 200, opacity: 0.8 }}
      animate={{ width: 340, opacity: 1 }}
      exit={{ width: 340, opacity: 0 }}
      transition={{ duration: 0.4, ease: [0.4, 0, 0.2, 1] }}
      className="bg-black rounded-b-2xl overflow-hidden flex items-center"
      style={{ minHeight: 28 }}
    >
      {/* Left wing */}
      <div className="flex items-center gap-1.5 pl-3 pr-2">
        <PulsingDot color="#66e8f8" />
        <span className="text-[12px]">🐢</span>
        <span className="font-mono text-[10px] font-bold text-transparent bg-clip-text" style={{ backgroundImage: 'linear-gradient(90deg, #66e8f8, #34d399)' }}>
          Working...
        </span>
      </div>

      {/* Spacer (camera area) */}
      <div className="flex-1" />

      {/* Right wing */}
      <div className="flex items-center gap-1.5 pr-3 pl-2">
        <span className="font-mono text-[10px] font-bold text-white/50">CodeIsland</span>
        <span className="font-mono text-[10px] font-bold text-green">×2</span>
      </div>
    </motion.div>
  )
}

// ─── Expanded Panel ───

function ExpandedPanel({ state }: { state: DemoState }) {
  return (
    <motion.div
      initial={{ width: 200, height: 28 }}
      animate={{ width: 380, height: state === "approval" ? 220 : state === "chat" ? 280 : 200 }}
      exit={{ width: 200, height: 28 }}
      transition={{ duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
      className="bg-black rounded-b-2xl overflow-hidden"
    >
      {state === "sessions" && <SessionsView />}
      {state === "chat" && <ChatView />}
      {state === "approval" && <ApprovalView />}
    </motion.div>
  )
}

// ─── Sessions View ───

function SessionsView() {
  const sessions = [
    { name: "CodeIsland", status: "进行中", statusColor: "#66e8f8", terminal: "cmux", time: "31m", emoji: "🐢" },
    { name: "icare", status: "已完成", statusColor: "#4ade80", terminal: "Terminal", time: "25m", emoji: "🐢" },
  ]

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.2 }} className="px-3 pt-1 pb-2">
      <div className="flex items-center justify-between mb-1.5 pb-1 border-b border-white/[0.06]">
        <span className="font-mono text-[9px] text-white/30">2 个会话</span>
        <span className="font-mono text-[9px] text-white/25">⚙</span>
      </div>

      {sessions.map((s, i) => (
        <div key={i} className="flex items-center gap-2 py-1.5 px-1 rounded hover:bg-white/[0.04]">
          <span className="text-[14px]">{s.emoji}</span>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-1.5">
              <span className="font-mono text-[10px] text-white/90 font-semibold">{s.name}</span>
              <span
                className="font-mono text-[8px] font-semibold px-1.5 py-0.5 rounded-full"
                style={{ color: s.statusColor, background: `${s.statusColor}22` }}
              >
                {s.status}
              </span>
            </div>
            <div className="font-mono text-[8px] text-white/30 mt-0.5">你: 帮我优化一下这个组件...</div>
          </div>
          <span className="font-mono text-[7px] text-white/30 px-1.5 py-0.5 rounded bg-white/[0.06]">{s.terminal}</span>
          <span className="font-mono text-[8px] text-white/25">{s.time}</span>
        </div>
      ))}

      <div className="text-center mt-1.5">
        <span className="font-mono text-[8px] text-white/15">显示全部 2 个会话</span>
      </div>
    </motion.div>
  )
}

// ─── Chat View ───

function ChatView() {
  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.2 }} className="px-3 pt-1 pb-2 flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center gap-1.5 mb-2 pb-1 border-b border-white/[0.06]">
        <span className="font-mono text-[9px] text-white/40">‹</span>
        <span className="font-mono text-[10px] text-white/80 font-semibold">CodeIsland</span>
      </div>

      {/* Messages */}
      <div className="flex-1 space-y-2 overflow-hidden">
        {/* User message */}
        <div className="flex justify-end">
          <div className="bg-white/10 rounded-xl px-2.5 py-1.5 max-w-[80%]">
            <span className="font-mono text-[9px] text-white/80">帮我把字体大小统一成设置页面的</span>
          </div>
        </div>

        {/* Assistant */}
        <div className="flex items-start gap-1.5">
          <div className="w-1.5 h-1.5 rounded-full bg-white/50 mt-1.5 shrink-0" />
          <span className="font-mono text-[9px] text-white/70">好的，我来检查所有 UI 文件的字体大小...</span>
        </div>

        {/* Tool call with diff */}
        <div className="pl-3">
          <div className="flex items-center gap-1">
            <div className="w-1.5 h-1.5 rounded-full bg-green shrink-0" />
            <span className="font-mono text-[9px] text-white/60 font-medium">Edit</span>
            <span className="font-mono text-[8px] text-white/30">已编辑 NotchView.swift</span>
          </div>
          <div className="mt-1 rounded border border-white/[0.06] overflow-hidden ml-2.5">
            <div className="bg-green/10 text-green/70 px-1.5 py-0.5 text-[8px] font-mono">+ .font(.system(size: 13))</div>
            <div className="bg-red-500/10 text-red-400/70 px-1.5 py-0.5 text-[8px] font-mono">- .font(.system(size: 9))</div>
          </div>
        </div>

        {/* Working indicator */}
        <div className="flex items-center gap-1.5 pl-0.5">
          <div className="w-1.5 h-1.5 rounded-full bg-orange-400 animate-pulse" />
          <span className="font-mono text-[9px] text-orange-400">工作中...</span>
        </div>
      </div>

      {/* Bottom bar */}
      <div className="mt-2 pt-1.5 border-t border-white/[0.06]">
        <div className="bg-white/[0.06] rounded-lg py-1.5 text-center">
          <span className="font-mono text-[9px] text-white/40">前往终端</span>
        </div>
      </div>
    </motion.div>
  )
}

// ─── Approval View ───

function ApprovalView() {
  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.2 }} className="px-3 pt-2 pb-2.5">
      {/* Header */}
      <div className="flex items-center gap-1.5 mb-2">
        <div className="w-2 h-2 rounded-full bg-orange-400" />
        <span className="font-mono text-[10px] text-orange-300 font-semibold">权限请求</span>
      </div>

      {/* Tool info */}
      <div className="flex items-center gap-1 mb-2">
        <span className="text-[10px]">⚠</span>
        <span className="font-mono text-[9px] text-white/80 font-medium">Write</span>
        <span className="font-mono text-[8px] text-white/40">src/components/App.tsx</span>
      </div>

      {/* Diff preview */}
      <div className="rounded-lg overflow-hidden border border-white/[0.06] mb-2.5" style={{ background: 'rgba(17,17,24,0.9)' }}>
        <div className="bg-green/10 text-green/70 px-2 py-0.5 text-[9px] font-mono">+ import &#123; ProManager &#125; from './Pro'</div>
        <div className="bg-green/10 text-green/70 px-2 py-0.5 text-[9px] font-mono">+ const pro = ProManager.shared</div>
        <div className="bg-red-500/10 text-red-400/70 px-2 py-0.5 text-[9px] font-mono">- // TODO: add license check</div>
      </div>

      {/* Diff summary */}
      <div className="flex gap-2 mb-2.5">
        <span className="font-mono text-[9px] text-green font-medium">+2</span>
        <span className="font-mono text-[9px] text-red-400 font-medium">-1</span>
      </div>

      {/* Buttons */}
      <div className="flex gap-1.5">
        <button className="flex-1 font-mono text-[9px] text-white/70 py-1.5 rounded-lg bg-white/[0.08] text-center">拒绝</button>
        <button className="flex-1 font-mono text-[9px] text-black font-semibold py-1.5 rounded-lg bg-green text-center">允许</button>
      </div>
    </motion.div>
  )
}

// ─── Helper Components ───

function PulsingDot({ color }: { color: string }) {
  return (
    <motion.div
      animate={{ opacity: [1, 0.4, 1] }}
      transition={{ duration: 1.5, repeat: Infinity, ease: "easeInOut" }}
      className="w-1.5 h-1.5 rounded-full shrink-0"
      style={{ background: color, boxShadow: `0 0 6px ${color}80` }}
    />
  )
}

function TerminalWindow({ title, children, className = "" }: { title: string; children: React.ReactNode; className?: string }) {
  return (
    <div className={`rounded-lg overflow-hidden border border-white/[0.08] shadow-2xl ${className}`} style={{ background: 'rgba(22,22,30,0.95)', backdropFilter: 'blur(20px)' }}>
      <div className="flex items-center gap-1.5 px-3 py-2 border-b border-white/[0.06]">
        <div className="w-2.5 h-2.5 rounded-full bg-[#ff5f57]" />
        <div className="w-2.5 h-2.5 rounded-full bg-[#febc2e]" />
        <div className="w-2.5 h-2.5 rounded-full bg-[#28c840]" />
        <span className="ml-2 font-mono text-[10px] text-white/40">{title}</span>
      </div>
      <div className="p-3 font-mono text-[11px] leading-relaxed">{children}</div>
    </div>
  )
}
