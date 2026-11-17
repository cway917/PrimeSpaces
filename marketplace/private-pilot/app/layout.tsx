import type { Metadata } from 'next';
import './globals.css';
import './brand.css';
export const metadata: Metadata = { title:'PrimeSpaces | Space Rental Marketplace', description:'Your private PrimeSpaces marketplace. Discover local facilities, request a space, and manage every gathering.', robots:{index:false,follow:false},icons:{icon:'/primespaces-logo.png'}};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>}
