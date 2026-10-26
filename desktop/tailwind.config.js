/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        synapse: {
          bg: '#0B0F19',
          surface: '#111827',
          card: '#1F2937',
          border: '#374151',
          primary: '#3B82F6',
          primaryHover: '#2563EB',
          accent: '#10B981',
          warning: '#F59E0B',
          danger: '#EF4444',
          text: '#F9FAFB',
          textMuted: '#9CA3AF'
        }
      }
    },
  },
  plugins: [],
}
