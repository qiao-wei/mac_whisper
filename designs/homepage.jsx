import React, { useState } from 'react';
import { 
  LayoutDashboard, 
  Clock, 
  CheckCircle, 
  Search, 
  ChevronDown, 
  FileVideo, 
  FileAudio, 
  Upload, 
  Settings, 
  RotateCcw,
  Film,
  Music,
  User,
  ChevronRight, // Added
  ChevronLeft   // Added
} from 'lucide-react';

export default function App() {
  const [activeTab, setActiveTab] = useState('All Projects');
  const [isRightPanelOpen, setIsRightPanelOpen] = useState(true); // State for panel visibility

  return (
    <div className="flex h-screen bg-[#0B0E14] text-white font-sans overflow-hidden selection:bg-blue-500 selection:text-white">
      {/* Sidebar */}
      <Sidebar activeTab={activeTab} setActiveTab={setActiveTab} />

      {/* Main Content Area */}
      <main className="flex-1 flex overflow-hidden relative">
        {/* Left Panel: Project List Wrapper */}
        <div className="flex-1 flex relative min-w-[300px]">
            {/* Scrollable Content */}
            <div className="absolute inset-0 overflow-y-auto p-8">
                <Header />
                <ProjectList />
            </div>

            {/* Toggle Button - Fixed on the right edge of the left panel */}
            <button
                onClick={() => setIsRightPanelOpen(!isRightPanelOpen)}
                className="absolute right-0 top-1/2 transform -translate-y-1/2 translate-x-1/2 z-20 bg-[#1f2430] border border-gray-700 text-gray-400 hover:text-white hover:bg-blue-600 hover:border-blue-600 p-1.5 rounded-full shadow-lg transition-all duration-200"
                title={isRightPanelOpen ? "Collapse Panel" : "Expand Panel"}
            >
                {isRightPanelOpen ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
            </button>
        </div>

        {/* Right Panel: New Project - Collapsible */}
        <div 
            className={`bg-[#0F1219] border-l border-gray-800 shadow-2xl z-10 transition-all duration-300 ease-in-out overflow-hidden flex flex-col justify-center
            ${isRightPanelOpen ? 'w-[450px] opacity-100' : 'w-0 opacity-0 border-none'}`}
        >
          <div className="w-[450px] p-8 flex-shrink-0"> {/* Inner wrapper to fix width during transition */}
            <NewProjectPanel />
          </div>
        </div>
      </main>
    </div>
  );
}

// --- Components ---

function Sidebar({ activeTab, setActiveTab }) {
  const menuItems = [
    { name: 'All Projects', icon: <LayoutDashboard size={20} /> },
    { name: 'In Progress', icon: <Clock size={20} /> },
    { name: 'Completed', icon: <CheckCircle size={20} /> },
  ];

  return (
    <div className="w-64 bg-[#080a0f] flex flex-col border-r border-gray-800 flex-shrink-0 transition-all duration-300">
      {/* User Profile / Logo Area */}
      <div className="p-6 flex items-center space-x-3 mb-6">
        <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-orange-400 to-pink-500 flex items-center justify-center text-white font-bold shadow-lg">
          <User size={20} />
        </div>
        <div>
          <h1 className="font-bold text-lg leading-tight">CaptionPro</h1>
          <p className="text-gray-400 text-xs">Welcome Back</p>
        </div>
      </div>

      {/* Navigation */}
      <nav className="px-4 space-y-2 flex-1">
        {menuItems.map((item) => (
          <button
            key={item.name}
            onClick={() => setActiveTab(item.name)}
            className={`w-full flex items-center space-x-3 px-4 py-3 rounded-lg transition-all duration-200 ${
              activeTab === item.name
                ? 'bg-blue-600 text-white shadow-md shadow-blue-900/20'
                : 'text-gray-400 hover:bg-gray-800 hover:text-gray-200'
            }`}
          >
            {item.icon}
            <span className="font-medium">{item.name}</span>
          </button>
        ))}
      </nav>
      
      <div className="p-4 text-xs text-center text-gray-600">
          v2.4.0
      </div>
    </div>
  );
}

function Header() {
  return (
    <div className="mb-8 max-w-5xl">
      {/* Top Icons */}
      <div className="flex items-center space-x-4 text-gray-400 mb-6">
        <button className="hover:text-white transition-colors p-1 hover:bg-gray-800 rounded-full"><RotateCcw size={18} /></button>
        <button className="hover:text-white transition-colors p-1 hover:bg-gray-800 rounded-full"><Settings size={18} /></button>
      </div>

      <h2 className="text-3xl font-bold mb-6 tracking-tight">All Projects</h2>

      {/* Search and Filter */}
      <div className="flex space-x-4 mb-2">
        <div className="relative flex-1 group">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-500 group-focus-within:text-blue-500 transition-colors" size={18} />
          <input
            type="text"
            placeholder="Search projects by name..."
            className="w-full bg-[#13161f] border border-gray-700 text-gray-200 pl-10 pr-4 py-2.5 rounded-lg focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-all placeholder-gray-600"
          />
        </div>
        <button className="flex items-center space-x-2 bg-[#13161f] border border-gray-700 px-4 py-2.5 rounded-lg text-gray-300 hover:border-gray-500 transition-colors min-w-[180px] justify-between">
          <span className="text-sm">Sort by: Last Modified</span>
          <ChevronDown size={16} />
        </button>
      </div>
    </div>
  );
}

function ProjectList() {
  const projects = [
    {
      id: 1,
      name: 'My Vacation Video.mp4',
      type: 'video',
      status: 'Completed',
      date: 'Today, 10:30 AM',
      color: 'green',
    },
    {
      id: 2,
      name: 'Podcast Interview Ep5.mp3',
      type: 'audio',
      status: 'Editing',
      date: 'Yesterday, 4:15 PM',
      color: 'yellow',
    },
    {
      id: 3,
      name: 'Product Demo.mov',
      type: 'video',
      status: 'Translating',
      date: 'June 5, 2024',
      color: 'orange',
    },
    {
      id: 4,
      name: 'Team Meeting Recording.wav',
      type: 'audio',
      status: 'Error',
      date: 'June 4, 2024',
      color: 'red',
    },
     {
      id: 5,
      name: 'Q3 Financial Review.mp4',
      type: 'video',
      status: 'Completed',
      date: 'June 1, 2024',
      color: 'green',
    },
    {
      id: 6,
      name: 'Marketing Campaign V2.mov',
      type: 'video',
      status: 'Editing',
      date: 'May 28, 2024',
      color: 'yellow',
    },
  ];

  return (
    <div className="space-y-3 max-w-5xl pb-10">
      {projects.map((project) => (
        <ProjectItem key={project.id} project={project} />
      ))}
    </div>
  );
}

function ProjectItem({ project }) {
  const getStatusStyle = (status, color) => {
    switch (color) {
      case 'green': return 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20';
      case 'yellow': return 'bg-yellow-500/10 text-yellow-400 border border-yellow-500/20';
      case 'orange': return 'bg-orange-500/10 text-orange-400 border border-orange-500/20';
      case 'red': return 'bg-red-500/10 text-red-400 border border-red-500/20';
      default: return 'bg-gray-700 text-gray-300';
    }
  };

  const Icon = project.type === 'video' ? Film : Music;
  const iconColor = project.type === 'video' ? 'text-blue-400' : 'text-purple-400';

  return (
    <div className="flex items-center p-4 rounded-xl bg-[#13161f] border border-transparent hover:border-gray-700 hover:bg-[#1a1e29] transition-all duration-200 cursor-pointer group">
      <div className={`p-3 rounded-lg bg-gray-800/50 mr-4 ${iconColor} group-hover:scale-110 transition-transform`}>
        <Icon size={24} />
      </div>
      
      <div className="flex-1 min-w-0 mr-4">
        <h3 className="font-semibold text-gray-100 truncate mb-1">{project.name}</h3>
        <p className="text-gray-500 text-xs">Size: 45MB • Duration: 12:30</p>
      </div>

      <div className="flex flex-col items-end space-y-2">
        <span className={`px-2.5 py-1 rounded-full text-xs font-medium flex items-center space-x-1.5 ${getStatusStyle(project.status, project.color)}`}>
           <span className={`w-1.5 h-1.5 rounded-full ${
               project.color === 'green' ? 'bg-emerald-400' : 
               project.color === 'yellow' ? 'bg-yellow-400' :
               project.color === 'orange' ? 'bg-orange-400' : 'bg-red-400'
           }`}></span>
           <span>{project.status}</span>
        </span>
        <span className="text-gray-500 text-xs font-medium">{project.date}</span>
      </div>
    </div>
  );
}

function NewProjectPanel() {
  const [dragActive, setDragActive] = useState(false);

  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    // Handle file drop logic here
  };

  return (
    <div className="text-center w-full max-w-sm mx-auto">
      <h2 className="text-2xl font-bold mb-2">Start a New Project</h2>
      <p className="text-gray-400 mb-8 text-sm">Get started by uploading a file or pasting a link below</p>

      {/* Upload Box */}
      <div 
        className={`border-2 border-dashed rounded-2xl p-8 mb-6 transition-all duration-200 flex flex-col items-center justify-center min-h-[220px]
          ${dragActive ? 'border-blue-500 bg-blue-500/5' : 'border-gray-700 bg-[#13161f] hover:border-gray-500'}`}
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
      >
        <div className="w-12 h-12 bg-gray-800 rounded-lg flex items-center justify-center mb-4 text-gray-400">
           <Upload size={24} />
        </div>
        <h3 className="font-semibold text-gray-200 mb-2">Drag & Drop Audio/Video File Here</h3>
        <p className="text-gray-500 text-xs mb-6">Supports MP3, WAV, MP4, MOV, etc.</p>
        <button className="bg-gray-800 hover:bg-gray-700 text-white text-sm font-medium py-2 px-6 rounded-lg transition-colors border border-gray-700">
          Choose File
        </button>
      </div>

      <div className="flex items-center justify-center w-full mb-6">
          <div className="h-px bg-gray-800 w-full"></div>
          <span className="px-3 text-gray-500 text-sm">or</span>
          <div className="h-px bg-gray-800 w-full"></div>
      </div>

      {/* Link Input */}
      <div className="text-left mb-6">
          <label className="block text-xs font-medium text-gray-400 mb-2 ml-1">Paste Audio/Video Link</label>
          <input 
            type="text" 
            placeholder="https://" 
            className="w-full bg-[#13161f] border border-gray-700 rounded-lg px-4 py-3 text-white placeholder-gray-600 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-all"
          />
      </div>

      <button className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3.5 rounded-lg shadow-lg shadow-blue-900/30 transition-all transform hover:-translate-y-0.5 active:translate-y-0">
        Start Extraction
      </button>
    </div>
  );
}
