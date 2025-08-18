#!/bin/bash
set -e

echo "🚀 Parli Development Setup"
echo "=========================="

# Check prerequisites
echo "Checking prerequisites..."

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter SDK not found. Please install Flutter first."
    echo "   Visit: https://docs.flutter.dev/get-started/install"
    exit 1
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    echo "   Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Please install Docker Compose first."
    exit 1
fi

echo "✅ Prerequisites check passed"

# Setup Flutter dependencies
echo ""
echo "📱 Setting up Flutter app..."
cd app
flutter pub get
echo "✅ Flutter dependencies installed"
cd ..

# Setup environment files
echo ""
echo "⚙️  Setting up environment configuration..."
if [ ! -f token-service/.env ]; then
    cp token-service/.env.example token-service/.env
    echo "✅ Created token-service/.env from example"
    echo "⚠️  Please edit token-service/.env and add your OpenAI API key"
else
    echo "✅ token-service/.env already exists"
fi

# Build and start services
echo ""
echo "🐳 Building and starting services..."
docker-compose up -d --build

# Wait for services to be healthy
echo "⏳ Waiting for services to be ready..."
sleep 5

# Check service health
if curl -f http://localhost:8000/healthz > /dev/null 2>&1; then
    echo "✅ Token service is healthy"
else
    echo "⚠️  Token service health check failed"
fi

echo ""
echo "🎉 Development setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit token-service/.env with your OpenAI API key"
echo "2. Run 'flutter run' in the app/ directory to start the mobile app"
echo "3. Token service is running at http://localhost:8000"
echo ""
echo "Useful commands:"
echo "  docker-compose logs -f    # View service logs"
echo "  docker-compose stop       # Stop services"
echo "  docker-compose down       # Stop and remove containers"