"""
HealthPulse Setup Script
Generates data, trains model, and launches dashboard
"""

import os
import sys
import subprocess
import time

def run_command(command, description):
    """Run a command and handle errors"""
    print(f"\n🔄 {description}...")
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        print(f"✅ {description} completed successfully!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ {description} failed!")
        print(f"Error: {e.stderr}")
        return False

def check_dependencies():
    """Check if required packages are installed"""
    required_packages = ['pandas', 'numpy', 'scikit-learn', 'xgboost', 'streamlit', 'plotly']
    missing_packages = []
    
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            missing_packages.append(package)
    
    if missing_packages:
        print(f"❌ Missing packages: {', '.join(missing_packages)}")
        print("📦 Installing dependencies...")
        return run_command("pip install -r requirements.txt", "Installing dependencies")
    else:
        print("✅ All dependencies are installed!")
        return True

def setup_healthpulse():
    """Main setup function"""
    print("🏥 HealthPulse Setup")
    print("=" * 50)
    
    # Check dependencies
    if not check_dependencies():
        return False
    
    # Generate health data
    if not os.path.exists('health_data.csv'):
        if not run_command("python data_generator.py", "Generating synthetic health data"):
            return False
    else:
        print("✅ Health data already exists!")
    
    # Train ML model
    if not os.path.exists('health_model.pkl'):
        if not run_command("python ml_models.py", "Training ML model"):
            return False
    else:
        print("✅ ML model already exists!")
    
    # Run tests
    print("\n🧪 Running tests...")
    test_result = run_command("python -m pytest test_health_models.py -v", "Running test suite")
    
    print("\n" + "=" * 50)
    print("🎉 HealthPulse setup complete!")
    print("\n📊 Ready to launch dashboard:")
    print("   streamlit run healthpulse_app.py")
    print("\n🔗 Or visit: http://localhost:8501")
    
    # Ask if user wants to launch dashboard
    launch = input("\n🚀 Launch dashboard now? (y/n): ").lower().strip()
    if launch in ['y', 'yes']:
        print("\n🌐 Launching HealthPulse dashboard...")
        os.system("streamlit run healthpulse_app.py")
    
    return True

if __name__ == "__main__":
    success = setup_healthpulse()
    sys.exit(0 if success else 1)