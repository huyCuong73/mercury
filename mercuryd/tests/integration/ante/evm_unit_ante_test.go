package ante

import (
	"testing"

	evm "github.com/huyCuong73/mercury"
	"github.com/stretchr/testify/suite"

	"github.com/huyCuong73/mercury/mercuryd/tests/integration"
	"github.com/huyCuong73/mercury/tests/integration/ante"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestEvmUnitAnteTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.AnteIntegrationApp](integration.CreateEvmd, "evm.AnteIntegrationApp")
	suite.Run(t, ante.NewEvmUnitAnteTestSuite(create))
}
