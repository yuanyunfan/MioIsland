import { motion } from "motion/react"
import { Download } from "lucide-react"
import MacBookMockup from "./MacBookMockup"
import { useI18n } from "../lib/i18n"
import logo from "../lib/logo"

const GithubIcon = ({ size = 16 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
    <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
  </svg>
)

export default function Hero() {
  const { t } = useI18n()

  return (
    <section className="relative min-h-[100svh] overflow-hidden noise">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_120%_80%_at_50%_-20%,#1a1650_0%,#050510_60%)]" />
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_80%_20%,rgba(124,58,237,0.08)_0%,transparent_50%)]" />
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_20%_80%,rgba(52,211,153,0.04)_0%,transparent_40%)]" />
      <div className="absolute inset-0 opacity-[0.02] hidden sm:block" style={{ backgroundImage: 'linear-gradient(rgba(124,58,237,0.3) 1px, transparent 1px), linear-gradient(90deg, rgba(124,58,237,0.3) 1px, transparent 1px)', backgroundSize: '60px 60px' }} />

      <div className="relative z-10 max-w-6xl mx-auto px-4 sm:px-6 pt-20 sm:pt-28 pb-12 sm:pb-20">
        <div className="text-center mb-8 sm:mb-12" style={{ animation: 'heroEnter 1s ease-out both' }}>
          <div className="flex items-center justify-center gap-3 mb-4 sm:mb-6">
            <img src={logo} alt="CodeIsland" className="w-8 h-8 sm:w-10 sm:h-10 rounded-lg" />
          </div>

          <h1 className="font-display text-3xl sm:text-5xl md:text-7xl lg:text-8xl font-extrabold tracking-tight leading-[0.95]">
            <span className="text-text-primary">{t("hero.title1")}</span>
            <br />
            <span className="text-text-primary">{t("hero.title2")}</span>
            <span className="text-transparent bg-clip-text" style={{ backgroundImage: 'linear-gradient(135deg, #34d399, #6ee7b7, #a78bfa)', backgroundSize: '200% 200%', animation: 'gradient-shift 5s ease-in-out infinite' }}>
              {t("hero.title3")}
            </span>
          </h1>

          <p className="text-sm sm:text-base sm:text-lg text-text-muted mt-4 sm:mt-6 max-w-xl mx-auto leading-relaxed px-4">
            {t("hero.subtitle1")}<br />{t("hero.subtitle2")}
          </p>

          <div className="mt-6 sm:mt-8 flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center px-4 sm:px-0" style={{ animation: 'heroEnter 1s ease-out 0.15s both' }}>
            <a href="https://github.com/xmqywx/CodeIsland/releases" className="group flex items-center justify-center gap-2.5 bg-green text-deep px-6 sm:px-8 py-3 sm:py-3.5 rounded-xl font-mono text-sm font-bold transition-all duration-300 hover:shadow-[0_0_40px_rgba(52,211,153,0.3)] hover:scale-[1.03]">
              <Download size={16} />
              {t("hero.download")}
            </a>
            <a href="https://github.com/xmqywx/CodeIsland" className="group flex items-center justify-center gap-2.5 glass px-6 sm:px-8 py-3 sm:py-3.5 rounded-xl font-mono text-sm text-purple-pale transition-all duration-300 hover:scale-[1.03] hover:text-text-primary">
              <GithubIcon size={16} />
              {t("hero.star")}
            </a>
          </div>
        </div>

        {/* MacBook Mockup — hidden on very small screens */}
        <div className="hidden sm:block">
          <MacBookMockup />
        </div>
      </div>

      <motion.div animate={{ y: [0, 8, 0] }} transition={{ duration: 2.5, repeat: Infinity, ease: "easeInOut" }} className="absolute bottom-6 left-1/2 -translate-x-1/2 z-10 flex flex-col items-center gap-1.5 opacity-30 hidden sm:flex" style={{ animation: 'heroEnter 1s ease-out 1.5s both' }}>
        <div className="w-px h-6 bg-gradient-to-b from-transparent via-purple-light/30 to-transparent" />
        <span className="font-mono text-[9px] text-purple-light/50 uppercase tracking-[0.2em]">scroll</span>
      </motion.div>
    </section>
  )
}
